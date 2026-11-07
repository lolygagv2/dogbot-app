# App → Relay: schedule list fixes — shipped in Build 174 (2026-11-07)

1. **Labels.** Card title = mission label, never the dog's name (dog moved to the second line).
   `mission_type` silent_guardian / coach → entry `name`, falling back to "Silent Guardian" /
   "Coach mode" (en + ko). Training entries → `name`, else the catalog label for
   `mission_type` / `mission_name`. `source: "relay_settings"` entries get a small assistant
   marker with a "Scheduled by WIM-Z assistant" tooltip.
2. **Delete.** Still `delete_schedule` to the robot. `schedule_deleted` with `success:false` and
   an error containing "not found" is treated as already deleted: removed, no error shown.
3. **No stale cache.** `get_schedules` is sent on screen open (as before) and now after every
   `schedule_deleted`, and after a delete timeout/failure. The list is always redrawn from
   `schedules_list`; a failed delete no longer re-inserts the old row optimistically.
   Parsing is now lenient (`schedule_id`/`id`, `mission_name`/`mission_type`/`name`,
   `start_time`/`time`, missing `end_time`, short or long day names, missing `type`). Before
   this, one row without `mission_name` threw inside the WS listener and the whole
   `schedules_list` was dropped, which is the most likely reason the app kept showing stale
   entries.
4. **One delete per tap.** The app only ever sent one frame per swipe; the second frame ~18 s
   later came from the 10 s timeout re-adding the card and the user swiping again. Now a delete
   for an id already in flight is ignored, and the timeout path refreshes instead of re-adding.

Traces: `schedules-list`, `schedules-refresh`, `schedule-deleted`, `schedule-delete-*`,
`schedule-parse-skip` in Settings → Connection Diagnostics.

## Addendum — your second brief ("schedule list (AI-made schedules)"), Build 175

Items 1, 4, 5, 6 were already in Build 174 (above). Build 175 adds:
2. **Mode details.** `kind: "mode"` rows show "Daily at 3:00 AM · 30 min" (from `duration_s`);
   no stages/treats are rendered. Mode and relay_settings rows don't open the legacy editor.
3. **Next run.** `next_fire_at` → "Next: today 3:00 AM" / "tomorrow 3:00 AM" / "Mon 3:00 AM"
   in the phone's locale. `next_fire_at` null + `reason` → row greyed out with the reason.
7. **GET /missions** is no longer called; the Missions screen / schedule editor use the
   cached/predefined catalog.
8. **Drafts.** No REST hydrate of `/missions/drafts` any more; Approve/Decline tiles are only
   rendered for legacy rows that already exist in the feed.
The parser reads every field in your sample row (`schedule_id`, `mission_id`, `name`,
`mission_type`, `mission_name`, `kind`, `source`, `dog_id`, `start_time`, `end_time`,
`days_of_week`, `duration_s`, `enabled`, `next_fire_at`, `reason`).
