# Robot-Side Issues — Captured 2026-05-28 (Build 106 testing)

App-side Build 106 fixes shipped in parallel (force_trick now carries
`dog_id`/`dog_name`; unpair recovers from relay errors locally; active
device forced "online" in manage-devices). The items below cannot be
solved app-side and need work on the robot / relay side.

For carryovers from 2026-05-27 see `.claude/ROBOT_ISSUES_2026-05-27.md`
(Issues R1 spin classifier false positive, R2 bark spam).

---

## Issue R3 — Coach mode TTS skips the trick prompt audio

**When:** Build 104/105/106 testing sessions, repeated.

**Symptom:** User taps a trick chip in coach mode (e.g. "Sit"). App
sends `force_trick`. Robot is expected to TTS the trick name to cue the
dog. The audio prompt does not consistently play — operator hears no
"Sit" callout, but the robot still enters the wait window and (if the
dog happens to sit) issues a reward.

**Suspect surface:** the coach engine's `force_trick` handler (likely
`orchestrators/coaching_engine.py` per CLAUDE.md). Either the TTS call
is fire-and-forget without checking the audio system is free, or there
is a race where the wait-window starts before the prompt actually plays
through the speaker.

**App can't fix this.** App now sends a payload including `dog_id` /
`dog_name` so the robot's TTS template can substitute the dog's real
name into the prompt — but it can't make the robot speak when it
chooses not to.

**Suggested investigation:**
1. Wrap the trick-prompt TTS in a synchronous "speak then unblock"
   sequence — wait-window must not begin until audio playback returns.
2. Emit a `coach_trick_prompted` event back over WS once the audio has
   actually finished playing. The app can then display visual
   confirmation and surface a fault if the event never arrives.
3. Guard against re-entry: if a previous trick's audio is still playing
   when `force_trick` arrives, queue or drop with a logged warning.
4. Verify the audio system isn't being suppressed by the bark-detection
   self-mute gate (would interlock badly with R2 if added there).

**App-side instrumentation already available:** Coach screen renders
the trick chip with a highlight on `lastRewardBehavior` and shows the
reward count. Cross-reference these against the robot's TTS log.

---

## Issue R4 — Coach prompts call dog by generic "Dog"

**When:** Build 104/105 testing.

**Symptom:** Coach mode voice prompts say generic "Dog" instead of the
profile name. User has profiles set up; ArUco detection may or may not
have fired at the moment of the prompt.

**App-side change shipped in Build 106:** `force_trick` payload now
carries `{dog_id, dog_name}` resolved in priority order — detected
(ArUco) > selected profile > refuse-and-snackbar. If neither is
available the command is not sent.

**Robot-side ask:** Update TTS templates to substitute `dog_name` from
the `force_trick` payload when present. Continue to fall back to the
last `select_dog` value (relay-side stored, already wired) when the
payload omits it. The generic "Dog" string should only appear when
both the payload AND the last `select_dog` are absent — which Build
106 makes unlikely.

**Also worth confirming:** the same substitution happens for
*autonomous* coach rewards (no `force_trick`, robot picks the trick
itself) — those rely entirely on ArUco detection or `select_dog`
state; if the dog hasn't been identified the prompt should skip the
name rather than say "Dog".

---

## Issue R5 — Unpair device returns HTTP 500 on first attempt

**When:** Build 104/105 testing. Reproducible across sessions until
app cold-restart.

**Symptom:** User taps "Unpair" on a paired device in Settings →
Manage Devices. Relay returns HTTP 500. After fully closing and
re-opening the app, the same operation succeeds.

**App-side mitigation shipped in Build 106:** `paired_devices_provider`
now treats a 500 from the unpair endpoint identically to the existing
404 "orphan" path — falls back to local dismissal so the user is
unblocked without restart. The pairing row may stay orphaned on the
relay until the actual cause is fixed.

**Suspect surfaces (in order of likelihood):**
1. **Relay-side error mapping.** Orphaned pairings (no matching device
   row) should return 404, not 500. Some code path is throwing an
   uncaught exception inside the unpair handler instead of returning a
   structured response.
2. **Stale JWT.** App reads the auth token at provider construction
   and passes it on every request. If the token has refreshed inside
   the relay's expectation but not yet inside the app's
   `device_api_provider`, the relay may be returning 500 instead of
   401 for the rejection. App fix would be to add a 401 → refresh →
   retry interceptor — but only worth doing if (1) is confirmed not
   the cause.
3. **Race on a recently-paired device.** The unpair handler may not
   tolerate being called before some background reconciliation
   completes.

**Suggested investigation:**
1. Pull relay logs for an unpair-500 incident. Operator can repro
   easily — just open Manage Devices and hit Unpair on the first
   open of the day. Note the request timestamp; correlate with relay
   exception trace.
2. Wrap the unpair endpoint handler in a top-level try/except that
   returns 404 for "device not found" and a structured 5xx with a
   reason code for true server errors.
3. Verify the blind-unpair carry-over from prior sessions — the
   relay should accept `(user_id, device_id)` and idempotently remove
   the pairing row without insisting the device row exist.

**App-side notes for the relay team:**
- App's `DeviceApi.unpairDevice` POSTs to `ApiEndpoints.unpairDevice`
  with `{device_id}` and `Authorization: Bearer <jwt>`.
- App now treats {200, 404, 500} as "user has been unblocked";
  {401, 403, 409, 503} still surface as user-facing errors.

---

## Carry-forward verification (when robot ships fixes)

- **R1 (spin false positive):** trigger coach mode in a constrained
  space; watch for spurious rewards. Cross-reference with the in-app
  notifications feed (`notifications_provider`).
- **R2 (bark spam):** 5-minute coach session in a quiet room, count
  bark events in the in-app activity feed. Build 106 routes barks to
  in-app only by default — the cleanup measure is on the robot, not
  the app's notification routing.
- **R3 (trick TTS):** force each of the 5 default tricks; confirm the
  audio actually plays through the robot speaker before the wait
  window starts. App will start surfacing a `coach_trick_prompted`
  ack once the robot emits it.
- **R4 (generic dog name):** trigger `force_trick` for a profiled
  dog. Confirm robot TTS says the dog's real name. App is now sending
  it; verify substitution.
- **R5 (unpair 500):** Manage Devices → Unpair on first session of
  day, before any cold restart. Confirm 200 (or proper 404) response.
