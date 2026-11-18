# App → Relay: demo replayer request shapes (2026-11-18)

Context: on 2026-11-17 Reset / Load good day / Load bad day / Jump 15:30 / Jump 17:00
were tapped for Bezik, then Elsa. Nothing landed on either dog and the robot did nothing.

## What the app sent (B176–B183) — the cause on the app side

| Button | Request | Body |
|---|---|---|
| Reset | POST /admin/replay/reset | none |
| Load good day | POST /admin/replay/load | `{"seed":"demo_good_day.json"}` |
| Load bad day | POST /admin/replay/load | `{"seed":"demo_bad_day.json"}` |
| Jump to 15:30 | POST /admin/replay/jump | `{"to":"15:30"}` |
| Jump to 17:00 | POST /admin/replay/jump | `{"to":"17:00"}` |

No dog_id or device_id anywhere, so `Replayer.load` fell back to `demo_dog` / `demo_robot`.
The panel's `replay_active` chip polled `GET /api/dogs/demo_dog/status`, so it said Yes while
Bezik's and Elsa's status said false. (`demo_dog` is named "Bezik" on the relay, and the app
merges same-name dogs, so it was invisible in the app.)

## What the app sends from the next build

Every call carries the dog selected in the app and the device_id of the online robot.
The app sends NO `date`: the relay decides where a seed lands.

| Button | Request | Body |
|---|---|---|
| Reset | POST /admin/replay/reset | `{"dog_id","device_id"}` |
| Load good day | POST /admin/replay/load | `{"seed":"demo_good_day.json","dog_id","device_id"}` |
| Load bad day | POST /admin/replay/load | `{"seed":"demo_bad_day.json","dog_id","device_id"}` |
| Jump | POST /admin/replay/jump | `{"to":"HH:MM","dog_id","device_id"}` |
| Start | POST /admin/replay/start | `{"speed":120,"dog_id","device_id"}` |
| Pause | POST /admin/replay/pause | `{"dog_id","device_id"}` |
| (poll) | GET /admin/replay?dog_id=&device_id= | |
| (poll) | GET /api/dogs/{selected dog}/status | reads `replay_active` |

`device_id` is omitted when no robot is online.

## Please confirm or correct — the app will match whatever you settle on

1. **Date-relative seeds.** Final body for load: is `{seed, dog_id, device_id}` enough for
   "good day lands on yesterday for the recap and replays as today; bad day replays as
   today", or do you want a parameter (e.g. `mode`, `as_of`, a different seed name)?
   Are the seed file names still `demo_good_day.json` / `demo_bad_day.json`?
2. **reset / jump / start / pause with dog_id + device_id.** In the repo these take no
   target (singleton replayer). Will they honour the body's dog_id/device_id, 409 when the
   loaded replay is for another dog, or ignore them? Reset in particular: should it delete
   replay data for the dog in the body even when nothing is loaded for it?
3. **Response fields the panel shows.** After load/jump the panel prints one line:
   seed, dog, date, events landed. The app reads `name`/`seed`, `dog_id`, `date`, and
   `landed` if present, else `emitted`. For good day (yesterday landed + today replaying),
   which field is the count written by this call, and which date should the line show?
4. **Virtual clock.** The app shows `virtual_time` from the `/admin/replay` response only
   when its `dog_id` equals the selected dog. If you would rather put `virtual_time` on
   `GET /api/dogs/{dog}/status`, the app already reads it from there first.
5. **device_id = a real robot.** With a real online device_id, does the replay drive the
   robot (commands), or only write events against it? Last night's expectation was that
   the robot would act.
6. **`demo_dog`.** Still attached to Morgan's account, named "Bezik", 0 events. Safe to delete?

If the relay answers for a different dog than the one sent, the panel now shows
"Relay answered for X, not Y" instead of a success.
