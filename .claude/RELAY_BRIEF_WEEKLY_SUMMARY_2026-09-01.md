# App → Relay — new event/command from today's robot work + 2 confirms (2026-09-01)

**From:** App Claude (relayed via Morgan). Context: robot shipped a per-dog
weekly summary (robot 386aef0/7aa9231) and the data refactor closed
(dad2a97). App is at B159. The robot live-verified the LOCAL path
(/ws/local); the RELAY path is presumed working but unverified — hence
this brief.

## 1. NEW: `dog_weekly_summary_pull` command + `dog_weekly_summary` event

- **App → robot command** over the relay command channel:
  `{"command": "dog_weekly_summary_pull", "dog_id": "<uuid>", "dog_name": "..."}`
  — confirm the command channel passes it (if commands are allowlisted,
  add it; if pass-through like sg_status_pull/audio_loop, no action).
- **Robot → app event** `dog_weekly_summary` (robot sends `event` field,
  relay maps to `type` as usual). **Treat it as TRANSIENT**, exactly like
  `update_status` / `audio_state`:
  - do NOT add it to the replay/feed buffer — it is only ever a live
    reply to the pull; a stale summary replayed on reconnect would
    overwrite fresh data app-side,
  - NO FCM push event-type mapping — it must never push,
  - seq assignment is fine either way (the app carves the whole type out
    of its watermark).

## 2. CONFIRM (leftover from B155): sg_summary status_pull replies not feed-buffered

`sg_summary` with `action: "status_pull"` is a live reply (transient);
only the `action: "level4_escalation"` flavor is a real feed event.
Confirm the status_pull flavor isn't in the replay buffer. (If the relay
doesn't distinguish by action, buffering level4 only is the correct
split.)

## 3. CONFIRM: panic_alert PANIC-text push deployed

Decision on record (Morgan, 2026-09-01): panic alerts ride the EXISTING
generic push pipeline (same as "Treat dispensed") with the PANIC text —
no new event-type mapping. Confirm that's deployed, not just planned:
a `panic_alert` event should produce a lock-screen push with the robot's
pre-phrased message while the app is closed.

## 4. FYI only — no action

- Robot bark events now carry `bark_type`/`bark_label` in their payload
  (robot 8068ef3). This flows through automatically since the relay
  stores/forwards payloads verbatim — just never strip these fields if
  payload normalization is ever added.
- The robot-side data refactor (wimz.db, backfill) is storage-only:
  nothing about the robot→relay wire changed, nothing was re-emitted,
  and the relay DB is untouched. (The app's name-match dog merge for
  legacy relay rows remains in place until the relay DB purge — separate,
  pre-existing item.)
- `sg_summary.session_id` will change int→string when the robot retires
  its shim (app approved today). If the relay ever parses that field —
  it shouldn't — parse leniently.
