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
4. **DESIGN DECISION — Morgan approves or rejects, do not just ship:** sole-dog default. If exactly ONE dog profile is loaded on the robot, attribute otherwise-unresolved behavioral events to that dog with `id_method: "sole_dog"`. Honest for one-dog households, provenance-marked so it can be filtered or reversed later; NEVER applies when ≥2 profiles exist (a visiting dog would be misattributed).

## Relay owes

1. **Persist `dog_id` on activity_events rows** for `treat_dispensed`, `mission_started`, `mission_completed`, `guardian`/`guardian_alert`, `bark`, `behavior_flag` — top-level column, not just inside payload (the app's REST hydration reads row-level `dog_id`; it already does for bark/coach_reward). Pass `dog_name`/`id_method` through in `payload`.
2. *(Carried from 2026-07-12)* Add `audio_state` to `FEED_WORTHY_EVENTS` so now-playing survives an app reconnect mid-song.

## What nobody does

- No display-time assignment of untagged events to the selected dog (the Build 125 fake-data rule). Untagged means untagged.
- No backfill of historical rows in this pass.

## Verification (once robot side lands)

1. Select dog A in app → Give Treat → event arrives with `dog_id`=A → feed shows "For A", A's per-dog stats count it. Select no dog → untagged, still dispenses.
2. Start mission for dog A → mission_start/complete both attributed (check via History filtered to A).
3. SG session where ArUco resolves → escalation + reward events carry the id.
4. Two profiles loaded → unresolved events stay NULL (sole-dog rule must NOT fire).
