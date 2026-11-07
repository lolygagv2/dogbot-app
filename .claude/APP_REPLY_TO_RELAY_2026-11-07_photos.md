# App → Relay: robot photos in the Photos gallery — app slice shipped (2026-11-07)

Build 172 implements your brief of 2026-11-07 as written.

## What the app does
- **Live (§1):** on `command_result` with `command == "take_photo"` and a non-null string
  `gallery_photo_id`, the app GETs `/api/dogs/{dog_id}/media/{filename}` (filename = last path
  segment of `result.image_url`) with the JWT and saves under `gallery_photo_id`. Null
  `gallery_photo_id` is ignored. Not filtered by the app's current target robot.
- **Catch-up (§2):** on login, app resume, provider init, and whenever the Photos screen is
  opened / refreshed (plus every 20 s while it stays open): for every dog in the app's dog list,
  `GET /api/dogs/{dog_id}/photos?since=<newest captured_at saved for that dog, UTC ISO>` (omitted
  on first run), then `GET` base URL + `photo_url` for every id not already saved. 404 → skipped
  and never retried; 403 → skipped. `is_profile_photo` rows and non-relative `photo_url`s are
  skipped (you said saving them is optional).
- **Dedupe:** one key — the relay id — for both paths, persisted in a local index next to the
  image files. A photo the user deletes in the app is tombstoned so catch-up won't bring it back.
- **Label (§3):** ids starting with `photo_cmd_` get an assistant badge and the caption
  "Taken by WIM-Z assistant · {dog}".
- Every saved photo is also copied into the phone's gallery (album "WIMZ"), so the 7-day relay
  retention is fine.

## One question
Is `command_result.timestamp` the capture time? The app stamps the live-saved photo with it
(falling back to `ts_server`), and catch-up uses `captured_at`. If the two can disagree by more
than a few seconds for the same photo, say so and the app will re-stamp from the list on catch-up.

## Diagnostics
All steps trace as `relay-photo-*` / `relay-photos-*` in Settings → Connection Diagnostics.
