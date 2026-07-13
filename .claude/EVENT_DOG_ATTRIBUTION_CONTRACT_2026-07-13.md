# Event → Dog Attribution Contract (2026-07-13)

**Audience:** robot Claude instance (primary), relay Claude instance (2 items).
**Problem:** events are only reliably attributed to a dog in coach mode (and partially barks since Build 125). Everything else — manual treats, Silent Guardian activity, mission lifecycle events — lands untagged. The app's per-dog analytics rule (spec C4) *excludes* untagged events from per-dog counts, so most real activity silently vanishes from a dog's stats and history.

**Principle:** attribute at the SOURCE with honest provenance; never guess at display time. `dog_id` stays NULL when identity is genuinely unknown (spec §4, `event.dog_id` nullable).

---

## App side — SHIPPED (Build 140, this repo)

1. **`dispense_treat` command now carries the dog.** When the owner taps Give Treat, the command `data` includes:
   ```json
   {"type":"command","command":"dispense_treat","device_id":"...",
    "data":{"dog_id":"<uuid-or-legacy-id>","dog_name":"Rex"}}
   ```
   Both fields are OPTIONAL (absent when no dog is selected). Old app builds send `data: {}` — nothing breaks.
2. **`start_mission` already carried `dog_id`** (C2, since earlier build) — unchanged.
3. **App now reads `dog_id` (and `dog_name`) from live `treat`, `reward`, `mission_start`, `mission_complete` payloads** — lenient nullable casts, absent fields are fine. Mission events additionally fall back to the dog the app started the mission for (locally tracked), so app-started missions are attributed even before the robot echo lands.
4. Detections, barks, and guardian events already read `dog_id` when present (Build 125).

## Robot owes

1. **Echo owner attribution on manual dispense.** When `dispense_treat` arrives with `dog_id`/`dog_name`, stamp BOTH onto the emitted `treat` / `reward` event payload and the persisted event row. Set provenance `id_method: "owner_selected"` (new enum value alongside `"qr"` — the human tapping the button is an identification method; spec §5 `dog_identified` taxonomy extends). Absent fields → emit untagged exactly as today.
2. **Stamp `dog_id` whenever vision/ArUco identity resolves, in ANY mode** — Silent Guardian escalations, SG-triggered treat rewards, detections in manual/idle. Attribution must not be a coach/mission-mode privilege; if `dog_identified` fired for the dog in frame, subsequent events in that engagement carry its id (`id_method: "qr"` or `"vision"`).
3. **Mission lifecycle events echo the locked dog.** `mission_start` / `mission_progress` / `mission_complete` payloads include the `dog_id` the mission was started with (from the `start_mission` command, or `schedule.dog_id` for scheduler-started missions — the schedule row already has it). This is the reliable path for scheduler-started missions the app never sees start.
4. **DECIDED by Morgan 2026-07-13 — always-assign fallback.** Every event gets a dog:
   - Exactly one profile loaded → that dog, `id_method: "sole_dog"`.
   - Multiple profiles → the LAST dog, `id_method: "last_dog"`, where "last dog" = most recent of (vision/ArUco identification, explicit `dog_id` in a command — dispense_treat / start_mission / play_voice / select_dog). Recommend resetting last-dog on profile reload/reboot to the sole or app-selected dog rather than carrying a stale one.

   **Guardrails that make always-assign safe:**
   - **Precedence is strict:** explicit attribution (command `dog_id`, mission's locked dog, live vision/ArUco resolution) ALWAYS beats the fallback. Never let "last dog" override a dog the owner just named — e.g. app-selected dog B gets the treat even if the camera last saw dog A.
   - **Provenance is mandatory:** every fallback-stamped event carries its `id_method`. The app persists it (notification metadata) so a guess stays distinguishable from an identification — that's what makes multi-dog misattribution auditable and correctable later.
   - **Ids must be app-canonical:** stamp the `dog_id` values delivered via `reload_dogs` (the app's UUIDv7 / legacy ids), never robot-local indices or relay-minted ids — per-dog stats match on exact id (see relay dog-id drift, RELAY_DOG_SYNC_CONTRACT_2026-07-12).

## Relay owes

1. **Persist `dog_id` on activity_events rows** for `treat_dispensed`, `mission_started`, `mission_completed`, `guardian`/`guardian_alert`, `bark`, `behavior_flag` — top-level column, not just inside payload (the app's REST hydration reads row-level `dog_id`; it already does for bark/coach_reward). Pass `dog_name`/`id_method` through in `payload`.
2. *(Carried from 2026-07-12)* Add `audio_state` to `FEED_WORTHY_EVENTS` so now-playing survives an app reconnect mid-song.

## What nobody does

- No display-time assignment in the APP (the Build 125 fake-data rule) — assignment happens robot-side at the source, with `id_method` provenance, or via the app's own explicit knowledge (command dog_id, app-started mission). Events that still arrive untagged (old robot firmware) stay untagged.
- No backfill of historical rows in this pass.

## Verification (once robot side lands)

1. Select dog A in app → Give Treat → event arrives with `dog_id`=A, `id_method`=`owner_selected` → feed shows "For A", A's per-dog stats count it. Even if the camera last identified dog B (`last_dog` must NOT win over the command's dog_id).
2. Start mission for dog A → mission_start/complete both attributed (check via History filtered to A).
3. SG session where ArUco resolves → escalation + reward events carry the id with `id_method` `qr`/`vision`.
4. Two profiles loaded, nothing resolved, no command context → events carry the LAST identified/commanded dog with `id_method`=`last_dog` (never a bare id with no provenance).
5. Single profile → everything attributed to it with `id_method`=`sole_dog`.
