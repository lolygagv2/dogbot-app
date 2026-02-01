# WHY BUILD 37 SUCKS - Comprehensive Analysis

**Date:** February 1, 2026
**Author:** APP Claude (analyzing APP, Relay logs, and referencing Robot issues)

---

## Issue 1: MP3 Upload Fails

### What Happened (02:54 local / 07:54 UTC)
```
07:54:43 - [LARGE-MSG] App(user_000003): command, 5MB - may affect connection stability
07:54:43 - [ROUTE] App(user_000003) -> Robot(wimz_robot_01): upload_song
07:54:44 - [SEND->ROBOT] wimz_robot_01: command
07:54:44 - Robot wimz_robot_01 disconnected        ← ROBOT CRASHED HERE
07:54:45 - Robot wimz_robot_01 connected           ← Robot reconnected 1 second later
```

### Root Cause
**THE ROBOT CRASHED/DISCONNECTED when receiving the 5MB WebSocket message.**

The flow was:
1. APP read the MP3 file ✅
2. APP encoded to base64 ✅
3. APP sent via WebSocket ✅
4. RELAY received the 5MB message ✅
5. RELAY forwarded to ROBOT ✅
6. **ROBOT received it and DISCONNECTED** ❌

### Responsibility: **ROBOT**
The robot cannot handle receiving large WebSocket messages. It likely:
- Has a WebSocket frame size limit
- Runs out of memory trying to buffer 5MB
- Has a blocking receive that times out

### Possible Fixes:
1. **ROBOT:** Increase WebSocket buffer size or handle large messages in chunks
2. **RELAY:** Split large uploads into chunks before forwarding
3. **APP:** Chunk the upload into smaller pieces (but this requires robot support)
4. **Alternative:** Use HTTP multipart upload to relay, have relay save file, send filename to robot

---

## Issue 2: Video Overlay Always Shows "IDLE" (Not Mission Name)

### What Happened
- App shows "Sit Training" in green mode selector
- Video overlay (rendered by robot) shows "IDLE"
- Disconnect between app state and robot's actual mode

### Root Cause
**The video overlay text is rendered BY THE ROBOT, not the app.**

The robot's `video_track.py` draws the status overlay on each video frame. It reads the mode from the robot's internal state. If that state shows "idle", that's what appears in the video.

The relay logs show at 08:30:42:
```
[ROUTE] App(user_000003) -> Robot(wimz_robot_01): start_mission
[SEND->ROBOT] wimz_robot_01: command
[ROUTE] Robot(wimz_robot_01) -> App(user_000003): mission_progress
```

The robot DID send a `mission_progress` event, so it acknowledged the mission. But the video overlay still shows "idle".

### Responsibility: **ROBOT**
The robot's video overlay code is not reading from the same mode state that sends WebSocket events. The mode FSM and video overlay are disconnected.

### Possible Fixes:
1. **ROBOT:** `video_track.py` needs to read mode from the same state that sends `mission_progress` events
2. **ROBOT:** When mission starts, set internal mode to "mission" BEFORE sending the progress event

---

## Issue 3: Duplicate Commands When Leaving Coach Screen

### What Happened (08:32:18 UTC)
```
08:32:18 - stop_coach
08:32:18 - set_mode
08:32:18 - stop_coach    ← DUPLICATE
08:32:18 - set_mode      ← DUPLICATE
```

### Root Cause
**APP sends `stopCoaching()` twice:**

In `coach_screen.dart`:
```dart
// Line 88-93: Back button
onPressed: () {
  if (coachState.isActive) {
    ref.read(coachProvider.notifier).stopCoaching();  // ← First call
  }
  context.pop();  // ← Triggers PopScope
},

// Line 47-52: PopScope
onPopInvokedWithResult: (didPop, _) {
  if (didPop && coachState.isActive) {
    ref.read(coachProvider.notifier).stopCoaching();  // ← Second call
  }
},
```

And `stopCoaching()` sends TWO commands:
```dart
void stopCoaching() {
  ws.sendCommand('stop_coach', {});        // Command 1
  _ref.read(modeStateProvider.notifier).setMode(RobotMode.idle);  // Command 2
}
```

So: 2 calls × 2 commands = 4 commands sent.

### Responsibility: **APP**
This is an APP bug. The back button and PopScope both call stopCoaching().

### Fix Required:
```dart
// In coach_screen.dart - back button
onPressed: () {
  // DON'T call stopCoaching here - let PopScope handle it
  context.pop();
},
```

---

## Issue 4: Schedule Disappears After Saving

### What Happened
1. User creates schedule in UI
2. UI shows "Schedule created" (optimistic)
3. User leaves schedule menu
4. On return, schedule is gone

### CORRECTION: Relay DOES Have Endpoints (per Relay Claude)
```
POST /schedules         - ✅ Implemented in Build 36
GET /schedules          - ✅ Implemented in Build 36
PUT /schedules/{id}     - ✅ Implemented in Build 36
DELETE /schedules/{id}  - ✅ Implemented in Build 36
POST /schedules/enable  - ✅ Implemented in Build 36
POST /schedules/disable - ✅ Implemented in Build 36
```

### Possible Root Causes:
1. **Field name mismatch:** App sends `schedule_id`, relay might expect `id`
2. **Storage issue:** Relay might be storing in-memory only
3. **User auth issue:** Schedules might not be associated with user correctly
4. **GET response parsing:** App expects `schedule_id` in response, relay might return `id`

### APP's JSON Format:
```json
{
  "schedule_id": "uuid-here",
  "mission_name": "sit_training",
  "dog_id": "dog-uuid",
  "type": "daily",
  "start_time": "08:00",
  "end_time": "12:00",
  "days_of_week": [],
  "enabled": true,
  "cooldown_hours": 24
}
```

### Debug Needed:
- Check relay logs at schedule creation time for any errors
- Verify field names match between app and relay
- Check if schedules are persisted to database or in-memory only

### Responsibility: **UNKNOWN - needs debug**
Could be APP (wrong field names) or RELAY (storage/response format)

---

## Issue 5: No AI Bounding Boxes in Coach Mode

### What Happened
- In coach mode, no OpenCV bounding boxes around dogs
- No dog names displayed
- Tricks still detected and rewarded correctly

### Root Cause
**The bounding boxes are drawn BY THE ROBOT's video_track.py.**

The detection works (robot sends `detection` events with dog info), but the video frame rendering doesn't include the boxes.

From relay logs:
```
08:31:43 - [ROUTE] Robot(wimz_robot_01) -> App(user_000003): detection
08:31:49 - [ROUTE] Robot(wimz_robot_01) -> App(user_000003): detection
08:31:55 - [ROUTE] Robot(wimz_robot_01) -> App(user_000003): detection
```

Detections ARE happening and being sent to app. The robot just isn't drawing them on the video.

### Responsibility: **ROBOT**
The robot's video rendering pipeline needs to:
1. Receive detection results from the AI
2. Draw bounding boxes on the video frame
3. Add dog names as text labels

---

## Issue 6: Mission Mode Instantly Goes to Idle

### What Happened
At 08:30:42:
```
start_mission sent
mission_progress received
```

Then user leaves missions screen. At 08:31:40:
```
stop_mission sent      ← WHO SENT THIS?
mode_changed received (to idle)
mission_stopped received
```

### Root Cause Investigation
Looking at the relay logs, `stop_mission` was sent from the APP at 08:31:40, about 58 seconds after starting.

Possible causes:
1. User explicitly tapped "Stop" button
2. Some auto-stop logic in the app
3. 3-second verification timer expiring (but that's only 3 seconds)

The missions_screen.dart doesn't have automatic stopping on navigation.

**Most likely:** User tapped the Stop button on the active mission card, OR the robot sent a `mission_stopped` event that the app didn't initiate.

Actually looking closer, TWO `mission_stopped` events were sent:
```
08:31:40 - mission_stopped
08:31:40 - mission_stopped   ← DUPLICATE from robot
```

### Responsibility: **MIXED**
- If robot is sending duplicate events: **ROBOT**
- If app is sending stop unintentionally: **APP** (but code review doesn't show this)

---

## Issue 7: Why AI Works Great on Xbox But Sucks on App

### Architecture Differences

**Xbox Controller (Local):**
```
[Xbox Controller] → [Robot Python Process] → [Hardware]
                         ↓
                    [AI Detection]
                         ↓
                    [Local Display/Recording]
```
- Zero network latency
- Direct hardware access
- Video rendered locally at full framerate
- Bounding boxes drawn immediately after detection

**App via Relay (Remote):**
```
[Phone App] → [Internet] → [Relay Server] → [Internet] → [Robot]
                                                              ↓
                                                         [AI Detection]
                                                              ↓
                                                         [WebRTC Encode]
                                                              ↓
                                          [Internet] ← [Relay Server]
                                              ↓
                                         [Phone App]
                                              ↓
                                         [WebRTC Decode & Display]
```

### Why It's Worse:

1. **Network Latency:**
   - Every command: App → Relay → Robot (100-300ms round trip)
   - Video: Robot → Relay → App (100-200ms additional delay)
   - Total lag: 200-500ms vs ~0ms for Xbox

2. **WebRTC Compression:**
   - Video is compressed for streaming
   - Quality reduced to maintain framerate
   - Bounding boxes (if drawn) get compression artifacts

3. **Buffering:**
   - WebRTC has playback buffers to smooth jitter
   - This adds 100-500ms additional delay
   - What you see is the PAST, not real-time

4. **State Synchronization:**
   - App maintains optimistic local state
   - Robot has actual state
   - These can drift apart
   - Events may be dropped or delayed

5. **Video Overlay Disconnect:**
   - On Xbox: One process does detection AND rendering
   - On App: Robot does detection, sends events, app shows UI separately
   - Video overlay text comes from robot state
   - App UI comes from WebSocket events
   - These are TWO DIFFERENT DATA PATHS

---

## Summary: Who Needs to Fix What

| Issue | APP | RELAY | ROBOT |
|-------|-----|-------|-------|
| MP3 Upload Crash |  |  | **Must fix WebSocket large message handling** |
| Video shows "idle" |  |  | **video_track.py needs to read mode correctly** |
| Duplicate stop commands | **Fixed Build 37.1** |  |  |
| Scheduler disappears | Check field names | Check storage | |
| No bounding boxes |  |  | **Draw boxes on video frames** |
| Mission auto-stops | Investigate | | Investigate |
| AI latency | Minor | Minor | Architecture |

### CORRECTIONS from Relay Claude:
1. **Scheduler endpoints** - RELAY says they ARE implemented in Build 36
2. **Upload event forwarding** - RELAY says it IS implemented, but robot crashed before sending any events

So the MP3 upload issue is 100% ROBOT - the robot disconnected/crashed when receiving the 5MB message:
```
07:54:44 - [SEND->ROBOT] command    ← relay sent upload
07:54:44 - Robot disconnected       ← robot crashed 0.7 seconds later
```

The relay CAN'T forward an event the robot never sends.

---

## Recommendations

### For Robot Team:
1. **CRITICAL:** Fix video overlay to show actual mode (mission/coach/etc)
2. **CRITICAL:** Draw bounding boxes on video frames
3. **HIGH:** Handle large WebSocket messages (or implement chunked upload)
4. **HIGH:** Send `upload_complete` event after processing upload_song

### For Relay Team:
1. **CRITICAL:** Implement `/schedules` REST endpoints
2. **HIGH:** Forward `upload_complete`/`upload_error` events from robot
3. **MEDIUM:** Consider chunking large WebSocket messages

### For App Team:
1. **FIX NOW:** Remove duplicate stopCoaching() call in coach_screen.dart
2. **DONE:** Upload timeout warning (Build 37)
3. **DONE:** Better scheduler error messages (Build 37)
4. **DONE:** Mode cycling fix (Build 37)

---

## The Fundamental Problem

**The robot was designed for LOCAL control (Xbox), not REMOTE control (App).**

The architecture assumes:
- Direct access to hardware state
- Video rendered on same device doing detection
- No network latency
- Single source of truth

The app architecture requires:
- State synchronization over network
- Video streamed separately from state
- Multiple sources of truth that must agree
- Graceful handling of network issues

**This is a significant architectural mismatch.** The robot needs to be updated to properly support remote operation, not just local Xbox control.
