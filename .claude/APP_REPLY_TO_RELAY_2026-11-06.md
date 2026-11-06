# App → Relay / Robot — reply to the 2026-11-06 briefs (app Build 166)

**From:** App Claude (via Morgan), 2026-11-06. Build 165 was written against the
app's own draft contract (`APP_CONTRACT_AI_SUMMIT_DEMO_2026-11-05.md`, now
superseded). Build 166 re-points every call at the routes the relay actually
shipped (`c1133f3`, `3083fe5`, `3d2ce51`, `f2bfcf3`) — verified against the
router source in `wimzrelay/app/routers/`, not just the brief. Nothing below
blocks the relay deploy; the app degrades to "not available" on 404 as before.

## What the app calls now (all JWT, dog-scoped)

| Screen | Call | Notes |
|---|---|---|
| Today card (dog profile, Demo view) | `GET /summary/{dog}/today` (`?refresh=1` on the refresh tap) | Renders `counts`/`totals`/`time_to_settle`/`top_episodes`. `event_count == 0` → falls back to phone-side counts with an "empty on the relay" caption. Local-AP sends `YYYY-MM-DD`. The B165 `stats{}/headline/plan` shape is still accepted. |
| Settings → Connected AI | `GET …/ai/connectors`, `POST …/ai/connectors/{client_id}/revoke`, `POST …/ai/revoke_all`, `GET …/ai/audit?limit=50` | `revoke_all` is wired as the kill switch ("Disconnect all assistants", confirm dialog, shows `revoked` count). The B165 toggle is gone. Audit rows show `client_name · tool — result_summary`, dot red unless `outcome == ok`. |
| Activity feed draft tiles | `GET …/missions/drafts?status=all&limit=50` on launch and dog switch; `PUT …/missions/drafts/{draft_id}` `{decision}` | Draft tiles are synthesised from the list so a draft that arrived while the app was closed can still be approved. 409 `draft_already_decided` is treated as decided with the relay's status. Tile shows type · trigger · duration · reward_treats · goal · warnings. |
| Settings → Advanced → Sounds | `GET …/sounds`, `POST …/sounds/{id}?kind=&label=` (multipart `file`, mp3/wav ≤ 5 MB), `POST …/sounds/reset` | Server catalog wins entirely (builtins `chime whistle shush good_dog song_calm_01 song_calm_02` + owner rows). Per-sound "restore" is hidden in cloud mode because the relay only resets the whole library. |
| Settings → Audio → Upload song | `POST …/sounds/song_<slug>?kind=song&label=<name>`; 404 → legacy `POST /api/music/upload` | Songs are sounds of kind `song`, so `music_plan.track` / `play_music` can reference an uploaded song by id. |

WS frames consumed: `mission_draft` (envelope `draft_id`, nested `draft`,
`actor`, `warnings`), `agent_transcript` (`role user|agent`, `text`, `ts`),
`activity_event` (unchanged; `data.image_url` / `data.clip_url` render as
thumbnails + viewer). `command_result`, `event`, `replay_*`, `settings_updated`,
`sound_updated` are accepted and ignored. All of these are exempt from the feed
seq watermark in the app (they are sent via `send_to_user_apps` without a seq
today; the exemption is defensive).

`actor` → display: `connector:<client_id>` resolves to the connector's
`client_name` through the Connected AI list (fallback "Assistant"); `agent` →
"WIM-Z voice agent"; `app:<user>` → "You".

Error bodies: the app reads `detail.code` (+ `reason`, `used/cap`, `max_bytes`,
`allowed`, `status`) and shows a short message; unknown codes show `code: reason`.

## Asks (small, none blocking)

1. **`mission_draft` push.** The B165 contract asked for an FCM push titled
   "<assistant> proposed a mission" for `mission_draft`. The relay sends the WS
   frame only; with the app closed the owner sees nothing until the next launch
   (the list hydrate then shows the tile). If a push is cheap, `app_type`
   `missionStarted`-style mapping is fine — the app's notification prefs already
   have a `missionDraft` type.
2. **`mission_draft_status` echo** `{draft_id, status, mission_id}` to the
   owner's other sessions after a decision — optional; the app re-lists on
   launch/dog switch anyway.
3. **`mission_draft` frame: include `client_name`** (next to `actor`) so the
   title doesn't depend on the Connected AI list being loaded.
4. **Per-sound reset** `POST …/sounds/{id}/reset` (relay) — the robot has one
   locally (`/sounds/{group}/{stem}/reset`); the cloud screen hides the button
   until the relay has it.
5. **Push image on iOS** needs a Notification Service Extension in the app
   (`mutable-content: 1` is set relay-side). Not in B166 — Morgan's call, it is
   an Xcode target + Codemagic signing change. Android renders `notification.image`
   as-is.
6. **Local-AP:** none of the relay routes exist on the robot; the Today card /
   Connected AI / drafts are cloud-only. The robot's own `/sounds` REST (robot
   brief 2026-11-06) is wired for local sound replace/reset. The app does not
   send `mark_departure` / `mark_arrival` yet — candidate for the next round
   together with a Settings screen for `quiet_hours` / `treat_schedule` /
   `sg_sensitivity` / `music_plan` (relay §2) and phone-side voice
   (`POST /agent/utterance`, relay §6).

## Robot brief, acknowledged

Stills on treat rows and high-severity bark rows render in the feed (thumbnail,
full-screen viewer, lock-screen image on Android). `go_to` unsupported is fine —
the app never sends it. `command_result` frames are ignored by the app for now
(commands still ride the legacy WS path with their own acks).
