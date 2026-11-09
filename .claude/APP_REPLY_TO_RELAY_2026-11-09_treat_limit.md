# APP REPLY → RELAY: Treat limit synced through the relay (app Build 177, 2026-11-09)

Re: APP BRIEF "Treat limit is now synced through the relay (relay 2026-11-09)".
All app-side items shipped in Build 177. Point-by-point:

## 1. Message unchanged ✅
`{"command":"mission_config","data":{"daily_limit_enabled":bool,"daily_limit":int}}` is
untouched (`settings_provider.dart` → `dailyLimitPayload()`), now with a CONTRACT comment so
nobody renames it. The app never sends `daily_limit` outside 1–100 (slider is 5–100).

## 2. Slider sends once, on release ✅
`Slider.onChanged` only moves the label; `onChangeEnd` persists + sends ONE `mission_config`.
Toggle = one message. Expect one `mission_config` per user action from Build 177 on.

**The "missions screen sent 26 mission_config in 10 s" is a misattribution.** Nothing in the
missions code path sends `mission_config` — the only sender in the whole app is the Settings
daily-limit tile (verified: single `sendCommand('mission_config')` call site; `git log -S` shows
one commit ever). 26 in 10 s = two or three slider drags on the pre-177 build (one message per
5-step increment). Fixed by this point; nothing to check on the missions side.

## 3. Real value from the relay ✅
New `treatScheduleProvider` GETs `/api/dogs/{dog_id}/settings/treat_schedule` (app JWT) for the
selected dog on: Settings open, selected-dog change, ~1.5 s after our own `mission_config`
(to show what the relay actually saved), and on the §5 push (foreground arrival or tap).
toggle = `value.daily_cap_enabled`, slider = `value.daily_cap`. The value is copied into the
phone's local settings (no send), so local storage can no longer be stale.
The tile also shows the hint "Changed by the voice assistant / a connected AI assistant / the
robot" when `updated_by` isn't the app, and "Applies to all your dogs" otherwise (relay
follow-up 2026-11-09: all dogs always match, so one dog's row is enough — the dog-specific
wording was dropped in B180).
404 on the key = "relay has no treat_schedule" → the tile silently keeps local values.

Request: please confirm the `updated_by` vocabulary. The app treats `app*` / `user*` / `owner*`
as "us" and anything else (`agent`, `connector:<id>`, `robot`…) as "changed elsewhere".

## 4. null cap = unlimited ✅ (already the case)
`/summary/{dog}/{date}` → `totals.treat_cap` null renders the treats stat as the bare count
(never "0" or blank; "x/null" can't happen). The Settings tile says "No daily limit — unlimited
auto-treats". `/api/dogs/{dog}/status` is not rendered by the app today (only the admin demo
panel reads it). Weekly `treat_cap` is not displayed, so the known limitation doesn't surface.

## 5. "Treat limit raised" push ✅
Handled under the existing `alert` type. `data.kind == "treat_limit_raised"` →
- tap (background or cold start): opens `/settings?focus=treat_limit` — Settings scrolls to and
  highlights the Daily treat limit tile and re-reads `treat_schedule`, so the owner sees the
  toggle off / new cap and can put it back with one tap.
- foreground arrival: no navigation, just the re-read.
Other `data.type` pushes with no `kind` now open the Activity tab on tap (previously taps did
nothing app-side). Please keep `kind` + `dog_id` in `data`; `actor` is logged in diagnostics.
Note: the app does not switch dogs on tap — moot now that all dogs share one value and the
multi-dog push text no longer names a dog.

## 6. Hourly limit — no action ✅
`max_per_hour` is parsed and preserved (`TreatSchedule.toJson` keeps the full value for any
future PUT); no UI.

## 7. Treat refusals — proposed reply shape (for the ROBOT team, cc relay)
The app now listens for refusals of `dispense_treat` and shows a snackbar:
"Daily treat limit reached (65/65). Resets at midnight." (or "Resets at {time}" when
`resets_at` is present), "Too many treats in a row — try again in a minute.",
"Treats are paused right now (outside the allowed treat window)." — en + ko. The cap snackbar
has a "Settings" action → the Daily treat limit tile.

**Proposed WebSocket shape (robot → app), reusing the app's existing `error` frame:**
```json
{"type":"error","code":"treat_cap_reached","command":"dispense_treat",
 "used":65,"cap":65,"resets_at":"2026-11-10T00:00:00+09:00","message":"optional"}
```
`code` ∈ `treat_cap_reached` | `treat_rate` | `treat_window_closed`. The parser is lenient and
ALSO accepts: UPPER_CASE codes; `{"type":"command_result","command":"dispense_treat",
"success":false,"code"|"reason"|"error":"treat_cap_reached","used":..,"cap":..,"resets_at":..}`
(fields may sit under `result`); or the code as the frame `type`. Robot team: pick one, tell us,
and we'll tighten. `resets_at` ISO-8601 (or epoch seconds) is optional but preferred — the
"midnight" wording is the fallback.
REST `POST /api/dogs/{dog}/command dispense_treat` is not used by the app, but the 429/403 bodies
in the brief are already mapped (`relay_error.dart`: `treat_cap_reached` with used/cap/resets,
`treat_rate`, `treat_window_closed`).

## Test plan (device pass pending)
1. Settings → toggle off/on, drag slider → relay log shows exactly one save per dog per action.
2. Voice agent "allow unlimited treats" → push arrives → tap → Settings opens scrolled to the
   tile (highlighted), toggle shows OFF, hint "Changed by the voice assistant".
3. Hit the cap, press Treat → snackbar with the reason (needs the robot reply shape above).

Diagnostics (Settings → Connection Diagnostics): traces `treat-limit`, `treat-refused`,
`push-tap`, `push-foreground`, `push-nav`, `dog-setting-get-error`.
