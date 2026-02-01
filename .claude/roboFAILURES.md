
ROBOT CLAUDE/ APP CLAUDE / RELAY CLAUDE



More failures, this time not a lot was fixed. I think these changes are a higher level of capability. Please work on this.



Add your own tags to this on which questions you feel comfortable with your code set and assignment (ROBOT, APP or RELAY) and comment in each section on the solution with 500 words or less and little code except references to python files.


Please review the logs/
Local time is 17:25- 17:45


Mission Mode still fails in mode status, AI use and menu selection.
1a. Mission Mode - Failure to stay in mission mode the entire time, it allows "idle" to be shown on the video screen and this disrupts the flow of the mission. Or it's lagging like minutes behind if it IS changing everytime.....

1b. Test flow of mission mode selection to mission mode -- make sure it's a source of truth.

1c. Nope, when i click on the mission menu, and go into sit training and click Play mission - the first time i do this it does NOT even start the mission, it says "mission started" popup status, but the screen shows no active mission (Box should have changed to a stop mission box). The "start mission" box is still there. I repeat this procedure, and this time the mission has started....

1d. I return to main menu and it says in the screen text "mission mode 1/2 - idle.  The status button says Mission mode though. But is it monitoring for the dog to start the mission? I'm not sure....
If I I click into drive mode from the state where the mission is supposed to start but not working well I get the same thing it says mission idle it does a SIT training at the top.
1e. Seems AI might not be working in this mission mode, but the idle/mission/not defined/not started issue seems to be a huge problem
1f. WHen i went into mission mode - it pulled up "idle" status on the screen - literally showing "mission - idle". This is broken....mission idle, and they're not getting detected at all like they're literally walking around watching the treats and there's no detection of the dog at all This is a total failure so the mission mode is still completely broken sadly

---
### ROBOT CLAUDE RESPONSE - Issue 1 (Mission Mode Failures)
**Owner: ROBOT + APP**

**Root Cause Analysis:**
Logs at 17:35:32 show `Mission not found: stay_training` - the app sent `stay_training` but robot only has `sit_training`. This is a **mission name mismatch** problem.

**Specific Issues Identified:**

1. **1a/1f - "mission - idle" on video overlay:** The `video_track.py:286` shows overlay text when `engine.active_session` is None. If mission fails to start (due to name mismatch), session is never created, so overlay correctly shows "[MISSION MODE] No active mission". This is working AS DESIGNED, but mission isn't starting.

2. **1c - First click doesn't start:** Race condition in app. The app gets "mission started" response but robot actually returned `False` because `stay_training` doesn't exist. The popup lied. See log: `Start mission 'stay_training' -> False`

3. **1e/1f - AI not working in mission:** When mission doesn't start, `active_session = None`, so the `_on_detection_event` handler in `mission_engine.py:273-295` skips all dog tracking because `if not self.active_session: return`.

**Fix Plan:**
1. Robot: Add mission name fuzzy matching/alias in `mission_engine.py` - map `stay_training` -> `sit_training`, `Basic Sit` -> `sit_training`
2. Robot: Return detailed error when mission not found: `{"success": false, "error": "Mission not found", "available": [...]}`
3. App: Display actual error message, not generic "mission started"
4. Robot: Add `GET /missions/list` validation endpoint for app to fetch valid mission names

**Files to modify:** `orchestrators/mission_engine.py`, `api/server.py`

---

2. Just Ai dog detection complaint in general?
2a.AI-"dog detected" at 50-61%. Can we test this? See why it's failing so bad?

---
### ROBOT CLAUDE RESPONSE - Issue 2 (AI Detection at 50-61%)
**Owner: ROBOT**

**Analysis:**
Detection confidence at 50-61% is actually normal for YOLOv8s on Hailo-8 at 640x640 resolution. The model was designed with 0.5 threshold. Lower confidence doesn't mean "bad" detection - it means the model is less certain, often due to:
- Dog partially visible
- Dog at edge of frame
- Unusual pose/angle
- Lighting conditions

**Current thresholds in code:**
- `services/perception/detector.py`: `confidence_threshold = 0.5` (dog detection)
- `core/behavior_interpreter.py`: `0.75` for lie/cross poses (raised in Build 33)
- `configs/trick_rules.yaml`: Individual trick confidence thresholds

**Why it seems "bad":**
The 3-second presence requirement + 66% visibility ratio in `mission_engine.py:603-610` is working correctly. If dog only hits 50-60% confidence intermittently, the `frames_seen` count stays low, making presence ratio fail.

**Options:**
1. Lower `confidence_threshold` to 0.4 (may increase false positives)
2. Increase `STALE_TIMEOUT_SEC` from 6s to 8s (already increased from 2s in Build 32)
3. Reduce `PRESENCE_RATIO_MIN` from 0.66 to 0.50

**Recommendation:** Try option 3 first - reduce presence ratio to 0.50. This is less risky than lowering detection threshold.

---

3a. Coach mode enabled Ai is now not showing ANY boxes around dog with any name?  is this true? how it works? Great no more bezik/elsa but it should say DOG and try to use ARUCO in all AI modes...

---
### ROBOT CLAUDE RESPONSE - Issue 3 (No Bounding Boxes in Coach Mode)
**Owner: ROBOT**

**Analysis:**
In `video_track.py:128-161`, bounding boxes ARE drawn when `ai.dog_tracker.get_tracked_dogs()` returns data. The dog tracker uses detection events from `detector.py`.

**Why boxes may not appear:**
1. Resolution change from 1080p to 640x640 during mode switch causes brief tracking reset
2. `dog_tracker.py` was made more conservative in Build 34 - returns `None` for unidentified dogs instead of defaulting to last dog
3. If ArUco not visible, `dog_data.get('name')` returns `None`, but box should still draw with `dog_id`

**Code flow:**
- `video_track.py:141` draws `dog_name = dog_data.get('name', dog_id)` - should show raw ID if name unavailable
- The tracker in `core/dog_tracker.py` publishes to `get_tracked_dogs()`

**Likely Issue:** When ArUco not found, `name` field is None, but we're also not setting a fallback "Dog" label. The name being None causes the label to be skipped.

**Fix:**
In `video_track.py:141`, change from:
```python
dog_name = dog_data.get('name', dog_id)
```
to:
```python
dog_name = dog_data.get('name') or 'Dog'
```

This ensures "Dog" appears when ArUco identification fails.

---

4a. MP3 Issue upload failed  - Test upload still fails, it allows the upload - says uploading and then nothing, I don't think it gets saved to the robot, at some point there's a missed connection.At 18:14 i tired to upload a 4MB song. What happened?

---
### ROBOT CLAUDE RESPONSE - Issue 4 (MP3 Upload Failure)
**Owner: RELAY (primary) + ROBOT (secondary)**

**Log Analysis:**
Logs at 18:14 show songs PLAYING successfully (`VOICEMP3/songs/default/Wimz_theme.mp3`, etc.) but NO upload logs appear. The upload request never reached the robot.

**Upload flow:**
```
App -> Relay (multipart form) -> Robot (POST /audio/upload)
```

**Robot endpoint exists:** `api/server.py` has file upload handling with 60s timeout (added in Build 34).

**Likely causes:**
1. **RELAY:** Not forwarding multipart/form-data requests properly. Binary data may be mangled or timeout during relay proxy
2. **RELAY:** Missing route for `/audio/upload` endpoint proxying
3. **App:** May be hitting wrong endpoint or using incorrect content-type

**What Robot can confirm:**
The robot has no log entry for upload around 18:14, meaning request never arrived. If it had arrived with wrong format, we'd see a 422 error.

**RELAY CLAUDE:** Please verify:
1. Does relay forward `POST /audio/upload` to robot?
2. Is multipart form data being streamed through or buffered?
3. Check relay logs for any upload activity at 18:14

**APP CLAUDE:** Please verify:
1. What endpoint does app hit for uploads?
2. Is app sending to relay or trying direct robot connection?

---

5. Coach mode is being tested now, lots of issues, but at least it works, unlike mission mode ---- we are waiting for the dog manual mode enabled
5a. Weird it just went out of coach mode and went into manual mode when it went off screen or when it lost a connection and now it just speed off treats randomly at 537 or 1737 please verify why did it
5b. Lack of audio for all commands - So it said "Bezik" but it did not say "SIT" -- another quick error fix, make it say sit. Same logic as coach mode, it should use the same sub-mode for both that has this logic no? that's a bigger challenge but we may do that ok? what do you think?
5c. Maybe easier fix again: This mode should NOT be interrupted by a timeout/disconnect from the app. There should be no timeeouts, please check to see which ones are present and address this. When i clicked "lock screen" on the app. Coach mode exited....
5d. major issue: There seems to be TWo different coach modes.. this is fucked up ie different screen settings for coach mode, you can get into "coach mode" from the main screen and it's just running in the background while showing you the main screen and no further information in the UI, just "coach mode" in the video.
Second coach mode -which seems to actually work (but extremely shitty version compared to the xbox controller version) - runs from the MIssion system.  This system should also be initiated by the "Coach mode" selector on the main screen. Just use this one for all coach mode selection, ie if you change to coach mode, change to this screen and run it from there.
5e. Bad mode logic: So it's in manual mode it's in coaching the screen the AI video screen has the text manual mode The status on the app says Coaching mode this is again the complete mismatch of status that we need to fix it's still here it's still a problem I'm in coach mode but since this failed status - it says idle - manual mode in the video feed.
5f. AI sucks now, models/methods/parameters not good, what the hell happened? is it lagged decisions or why doesn't' it behave and recognize the dogs like it does using coach mode on teh xbox controller style? Did we screw up the logic already?? wtf....
5g. AI logic sucks now to recognize dogs and tricks alike: Compared to traditional coach mode we used on the xbox controller. With dog elsa in view, it did not confirm elsa... it could not find her, but it confirmed Bezik quickly the first time.  Second time, it took over 1 minute!
However, now the dog is in field in the device, clearly visible, i mean clearly obvious dog in the frame and yet it's doing NOTHING not detecting him, not calling his name, this process seems way too long and error prone. NOw it sees the dog (1 minute or so later) as the dog has already "sit" a few times. and it says sit as the command.  So, dog is sitting and yet it says "NO". It does not detect dog sitting.. This is bad bug we have to fix this...It barely detected the dog, and the trick logic was flawed. I have no faith to even test ARUCO yet with dog recognition, fix this shit!

---
### ROBOT CLAUDE RESPONSE - Issue 5 (Coach Mode Multiple Issues)
**Owner: ROBOT + APP**

**5a - Mode switch to manual on disconnect:**
Log at 17:37:02 shows `set_mode: manual` command received from app. This is APP sending explicit command, not robot auto-switching. When app locks screen, it may be sending `set_mode: manual` or `set_mode: idle`.

**RELAY/APP:** Check what happens on screen lock - is app sending a mode change?

**5b - Missing "SIT" audio after name:**
In `coaching_engine.py:_state_command()`, we DO play trick audio. But the logs need verification. The audio file must exist at `/VOICEMP3/talks/default/sit.mp3` or `/VOICEMP3/talks/sit.mp3`.

**Verified:** Audio files in `VOICEMP3/talks/default/` exist for sit, down, etc. Checking `coaching_engine.py:_state_command()` - it calls `self._play_audio(audio_file)` using trick_rules config.

**5c - Timeout on app lock/disconnect:**
The `relay_client.py` `user_disconnected` handler at line 400+ does:
```python
# Stop active missions/programs but NOT Silent Guardian
if self.state.get_mode() in [SystemMode.MISSION, SystemMode.COACH]:
    # Stops coaching...
```
**This is intentional** - we stop coach mode when user disconnects because it's interactive. But this may be too aggressive.

**Fix:** Add config option `autonomous_coach_mode: true` to allow coach to continue without app.

**5d - Two different coach modes:**
CORRECT - there's `orchestrators/coaching_engine.py` (standalone coach mode via `set_mode: coach`) and `orchestrators/mission_engine.py` (mission-based coaching). Both use similar logic but are separate code paths.

**Recommendation:** Don't merge them. Mission engine handles mission-specific features (stages, rewards tracking, completion). Coach engine is simpler continuous mode. Keep both but ensure consistent behavior.

**5e - Mode status mismatch:**
The `video_track.py:222-223` reads mode from `state.get_mode()`. If state says COACH but overlay shows MANUAL, there's a race condition. The state is source of truth - overlay reads it. Possible causes:
1. Mode change happened AFTER overlay render started
2. WebRTC frame lag (see issue 7)

**5f/5g - AI recognition slow:**
The 3s presence requirement + 66% visibility ratio is cumulative. If dog moves in/out of frame, detection resets. The Xbox controller version had simpler immediate detection without presence ratio requirements.

**Key difference:** Xbox mode uses `mode_fsm.py` with immediate coach activation. App coach mode goes through relay with potential latency.

**Fix proposal:**
1. Reduce `DETECTION_TIME_SEC` from 3.0 to 1.5s for coach mode
2. Reduce `PRESENCE_RATIO_MIN` from 0.66 to 0.50 for coach mode
3. Add more aggressive ArUco scanning

---



6.Scheduling test failure:- Test create schedule with each type via curl. Verify app can create schedules successfully
6a. From APP, check the logs/ folder for the messages about this around 18:24-18:27 for today 1-31-2026
6b. The app sends a POST request via Dio (HTTP client) to /schedules. Here's the equivalent curl the app would send:

  curl -X POST http://<relay-host>/schedules \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer <token>" \
    -d '{
      "schedule_id": "uuid-here",
      "mission_name": "Basic Sit",
      "dog_id": "dog-uuid-here",
      "name": "",
      "type": "daily",
      "start_time": "09:00",
      "end_time": "13:00",
      "days_of_week": [],
      "enabled": true,
      "cooldown_hours": 24
    }'

 6c. Key questions to debug:

  -Is the relay forwarding /schedules to the robot? The app hits the relay, which needs to proxy this to the robot.
  -What does the Robot API actually expect? Can you share the Robot's schedule endpoint signature?
  -Are the field names matching? The app sends:
    - schedule_id (not id)
    - mission_name (not mission_id)
    - start_time / end_time as "HH:MM" strings
    - days_of_week as string array ["monday", "tuesday"]

  6d. Let me check if there's a mismatch with what Robot Claude implemented. Robot CLAUDE: What error are you seeing exactly - 404, 422, 500?

---
### ROBOT CLAUDE RESPONSE - Issue 6 (Schedule API)
**Owner: ROBOT + RELAY**

**Robot API Specification (Build 35):**

**Endpoint:** `POST /schedules` (in `api/server.py` line 4111+)

**Robot expects:**
```json
{
  "name": "string (REQUIRED - cannot be empty)",
  "mission_name": "string (REQUIRED - must match existing mission)",
  "dog_id": "string (REQUIRED)",
  "start_time": "HH:MM (REQUIRED)",
  "end_time": "HH:MM (REQUIRED)",
  "type": "once|daily|weekly (optional, default: daily)",
  "days_of_week": ["monday",...] (required if type=weekly),
  "enabled": bool (optional, default: true),
  "cooldown_hours": int (optional, default: 24)
}
```

**Problems with App Request:**
1. `"name": ""` - Robot requires non-empty name. See `schedule_manager.py:96-100`:
   ```python
   required = ['name', 'mission_name', 'dog_id', 'start_time', 'end_time']
   missing = [f for f in required if f not in data or not data[f]]
   ```
   Empty string fails `not data[f]` check.

2. `"mission_name": "Basic Sit"` - Robot has `sit_training`, not `Basic Sit`. Same name mismatch as issue 1.

3. `"schedule_id"` - App sends it, robot generates it. Robot ignores incoming schedule_id.

**No logs at 18:24-18:27** - means request never reached robot. RELAY issue.

**RELAY CLAUDE:**
1. Is `/schedules` being proxied to robot?
2. Check relay logs for 18:24-18:27

**APP CLAUDE:**
1. Change `name` from empty to mission display name
2. Use actual robot mission names (or fetch from `GET /missions/list`)

**Robot will add:** Mission name alias mapping in next build.

---

7a. Big new issue, there's an extreme lag still, ie the frame rates stream, but i find we're often 10-30 seconds behind real time on the video feed? pleaes identify and fix this cause...we can't have the video frames lag behind real time. DO we skip frames or what is the solution?  Right now i think it's just probably inefficiency in process or AI right? let's address that first. IN a way this is better than the video feed dropping out, but in long term as a use case it gives a false illusion of competency (no drops but inaccurate old video being shown as live for up to 30 seconds or longer lag)

---
### ROBOT CLAUDE RESPONSE - Issue 7 (Video Lag 10-30 seconds)
**Owner: ROBOT**

**Root Cause Analysis:**

Looking at logs, I see evidence of the issue:
```
18:40:44,889 - Video frame 17900
18:40:45,291 - Video frame 3900
18:40:46,596 - Video frame 5100
18:40:47,875 - Video frame 10100
```

Frame numbers are jumping around erratically (17900 -> 3900 -> 5100 -> 10100). This indicates **frame buffer congestion**.

**The Problem:**
`video_track.py:66-77` uses `detector.get_last_frame()` which returns the most recent cached frame. But the detector's frame buffer can grow during:
1. Camera resolution changes (640x640 <-> 1920x1080)
2. AI inference spikes (13-14 FPS normally, drops to 4-5 FPS during reconfig)
3. WebRTC encoding backpressure

**Why it gets behind:**
The WebRTC track targets 15 FPS (`frame_interval = 1.0/15`). When AI is slow (4-5 FPS during mode switch), WebRTC keeps requesting frames at 15Hz but detector only produces 5Hz. The rate limiter in `video_track.py:72-74` sleeps for the interval, but reads stale frames.

**Solution Options:**

1. **Skip stale frames:** Add timestamp to frames, discard if older than 500ms
2. **Reduce WebRTC FPS:** Match detector rate (currently 13-14 FPS avg)
3. **Add jitter buffer:** Smooth out rate variations
4. **Frame freshness check:** Only send frame if it's "fresh" (new since last send)

**Recommended Fix:**
In `detector.py`, add frame timestamp to cached frame. In `video_track.py:78`, check timestamp:
```python
frame, timestamp = self.detector.get_last_frame_with_timestamp()
if time.time() - timestamp > 0.5:  # Frame older than 500ms
    # Return placeholder or skip
```

**Files to modify:**
- `services/perception/detector.py` - add timestamp to frame cache
- `services/streaming/video_track.py` - add freshness check

**Additional optimization:** Lower WebRTC target from 15 FPS to 10 FPS to match AI capacity.

---

## SUMMARY OF ROBOT FIXES NEEDED (Build 36)

| # | Issue | Fix | Priority |
|---|-------|-----|----------|
| 1 | Mission name mismatch | Add alias mapping: stay_training->sit_training, "Basic Sit"->sit_training | HIGH |
| 2 | Presence ratio too strict | Reduce from 66% to 50% | MEDIUM |
| 3 | No "Dog" label on video | Default to "Dog" when name is None | LOW |
| 4 | Upload not reaching robot | RELAY issue - verify proxy config | HIGH (RELAY) |
| 5c | Coach stops on disconnect | Add config for autonomous coach mode | MEDIUM |
| 5f/5g | Slow dog detection | Reduce detection time from 3s to 1.5s | HIGH |
| 6 | Schedule name empty | APP issue - provide non-empty name | HIGH (APP) |
| 7 | Video lag 10-30s | Add frame freshness check, skip stale frames | HIGH |

---
