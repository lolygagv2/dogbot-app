# Relay → App: demo replayer (2026-11-18)

Reply to `.claude/APP_ASK_TO_RELAY_2026-11-18_replay.md`, as pasted by Morgan.

Your call list is right. dog_id is required on every call (422 without it). device_id is
optional everywhere and only used by load. The relay checks it belongs to the dog's owner,
otherwise it uses the dog's own robot.

1. Dates. {seed, dog_id, device_id} is enough. Seed names are unchanged.
   - demo_good_day.json: on load, the whole day is written silently onto yesterday (no
     pushes), and the same day is loaded to replay as today.
   - demo_bad_day.json: replays as today and leaves yesterday alone.
   - Each load first clears earlier replay data on the dates it writes, so loading twice
     never duplicates.
   - The seed must be for a dog the admin owns. Otherwise 404 dog_not_found or 403
     not_dog_owner. No demo_dog is ever created.
2. Reset / jump / start / pause. They honour dog_id.
   - One replay runs at a time.
   - start, pause, speed and jump for a dog that isn't loaded return 409 replay_other_dog
     with loaded_dog_id, status and seed. Nothing loaded returns 409 replay_not_loaded.
   - Load always works and takes over from another dog's replay. The other dog's replayed
     events stay until it's reset.
   - Reset {dog_id} always works, even when nothing is loaded for that dog. It deletes only
     that dog's replay-made data and stops the replay only if it's that dog's. It returns
     removed.
   - GET /admin/replay?dog_id= answers for that dog. If another dog's replay is running it
     returns status: "idle", your dog_id, virtual_time: null and busy_with: {dog_id, status,
     seed}. Show "Replay running on {busy_with dog}" rather than an error.
3. Response fields.
   - load returns landed (events this call wrote: good day = the yesterday recap, bad day =
     0), landed_date (yesterday or null), date (the replay day, today), seed, name, dog_id
     and settings_ignored.
   - For good day, show date = today, plus "recap: {landed} events on {landed_date}".
   - jump returns landed (written by this jump), removed (taken back by a backward jump) and
     virtual_time.
   - emitted stays as the running total.
   - A replay_landed WebSocket message {dog_id, date, landed} is sent after the recap is
     written.
4. Clock. GET /api/dogs/{dog}/status now has virtual_time and replay_date. Both are null
   unless that dog's replay is loaded.
5. Robot. A replay only records events to the app, labelled with the robot's device_id. It
   never commands the robot. That's intended.
6. demo_dog. Already gone (duplicate-dog cleanup at the 2026-11-18 restart). Can't be
   recreated.
7. Last night. All calls arrived and returned 200, but every one went to demo_dog on
   2026-11-17. Events did land there (20 on the first jump; 29 on the bad-day run, deleted
   by a reset).
