# Build 38 — APP CLAUDE Instructions

**Date:** February 1, 2026
**Priority:** Fix the ghost commands first. Everything else is secondary.

---

## Architecture Rules (NOT NEGOTIABLE)

These are locked in by the project owner. Do not deviate.

1. **Robot state is authoritative.** App displays what robot says, period.
2. **App is a thin display/command layer.** No caching state. No autonomous commands.
3. **App NEVER sends commands during screen navigation.** No `stop_mission`, `stop_coach`, or `set_mode` in `dispose()`, `PopScope`, or any lifecycle handler. Commands fire ONLY on explicit user tap.
4. **File transfers use HTTP, not WebSocket.** MP3 uploads go App → Relay (HTTP multipart).
5. **Schedules live on the robot.** Send schedule commands to robot via WebSocket, not relay REST.
6. **Mode changes are explicit only.** No implicit mode changes from navigation, timers, or lifecycle events.

---

## P0-A1: Stop Sending Ghost Commands (CRITICAL — ROOT CAUSE OF MULTIPLE BUGS)

**Problem:** App sends `stop_mission`, `stop_coach`, and `set_mode` commands when user navigates between screens. User did NOT tap stop. The app is acting on its own. This is the #1 reason missions "don't work" — they work fine until the app kills them.

**Evidence from relay logs:**
```
08:30:42 - start_mission sent
08:31:40 - stop_mission sent  ← APP SENT THIS, USER DID NOT TAP STOP
```

**Also confirmed:** Duplicate `stop_coach` + `set_mode` (4 commands sent when leaving coach screen):
```dart
// CURRENT BUG - coach_screen.dart
// Back button calls stopCoaching()
// PopScope ALSO calls stopCoaching()
// stopCoaching() sends stop_coach AND set_mode
// Result: 2 calls × 2 commands = 4 commands fired
```

### Fix Required — AUDIT EVERY SCREEN for these patterns:

1. **Search entire codebase** for `dispose()`, `PopScope`, `onPopInvokedWithResult`, `deactivate` that send WebSocket commands
2. **Remove ALL** `stop_mission`, `stop_coach`, `set_mode` calls from lifecycle/navigation handlers
3. **Commands fire ONLY from explicit button taps** with clearly labeled `onPressed` handlers
4. **Specifically fix `coach_screen.dart`:** Remove `stopCoaching()` from the back button handler, let PopScope be the single handler — OR remove it from PopScope and keep it on the button. Pick ONE path, not both.

```dart
// CORRECT PATTERN:
// Back button
onPressed: () {
  context.pop();  // Just navigate. That's it.
},

// PopScope - ONLY if user needs to confirm
onPopInvokedWithResult: (didPop, _) {
  // Do NOT send any commands here
  // If mission is active, show "Mission still running" toast
},
```

5. **Search for any `set_mode` calls triggered by screen transitions.** The mode flipping (Manual → Idle → Manual) is caused by the app sending mode commands when screens load/unload. Kill all of these.

**Search commands to find all offending code:**
```bash
grep -rn "dispose\|PopScope\|onPopInvoked\|deactivate" lib/ | grep -i "stop\|mode\|coach\|mission\|command\|send"
grep -rn "set_mode\|setMode\|stop_mission\|stop_coach\|stopCoaching\|stopMission" lib/
```

**Test:** Start a mission → navigate to home screen → navigate to drive screen → come back. Mission must still be running. No `stop_mission` in relay logs.

---

## P0-A2: Mission Screen — Don't Own State, Just Display It

**Problem:** Mission screen shows wrong state ("completed" when nothing ran, "No active mission" after starting).

**Fix:**
1. On entering mission screen, poll `GET /missions/status` from robot
2. Display EXACTLY what robot returns
3. Listen for `mission_progress` WebSocket events and update display
4. **Never set local mission state optimistically** — wait for robot confirmation
5. Start mission flow:
   - User taps "Start Sit Training"
   - App sends `start_mission` command
   - App shows spinner: "Starting..."
   - Wait for `mission_progress` event with `status: waiting_for_dog`
   - THEN show mission UI
   - If no event within 5 seconds → show error "Mission failed to start"

---

## P0-A3: Mode Display — Trust Robot, Nothing Else

**Problem:** App shows IDLE when robot is in Manual/Mission. Mode flips back and forth.

**Fix:**
1. **Single source of truth:** `mode_changed` WebSocket event from robot
2. **On connect/reconnect:** poll `GET /mode` from robot, display result
3. **Remove any local mode state** that could conflict
4. **Remove any `set_mode` calls from screen load/unload** (see P0-A1)
5. When mode is locked (mission active), grey out mode selector and show lock icon

---

## P1-A4: MP3 Upload — Switch to HTTP

**Problem:** 5MB base64 over WebSocket kills the robot's connection. WebSocket is the wrong transport for file transfer.

**New Architecture:**
```
App → HTTP POST multipart to Relay → Relay stores file → Relay sends 
WebSocket "download_song" to Robot with URL → Robot fetches via HTTP
```

**App changes:**
1. Replace WebSocket `upload_song` with HTTP POST to `https://api.wimzai.com/api/music/upload`
2. Send as multipart form data (NOT base64)
3. Include `dog_id` and `filename` as form fields
4. Show upload progress bar
5. On success response from relay, show "Upload complete"
6. On failure, show error (do NOT disconnect WebSocket)

```dart
Future<void> uploadMP3(File file, String dogId) async {
  final request = http.MultipartRequest(
    'POST', 
    Uri.parse('https://api.wimzai.com/api/music/upload'),
  );
  request.headers['Authorization'] = 'Bearer $token';
  request.fields['dog_id'] = dogId;
  request.files.add(await http.MultipartFile.fromPath('file', file.path));
  
  final response = await request.send();
  if (response.statusCode == 200) {
    showSuccess("Song uploaded");
  } else {
    showError("Upload failed");
  }
}
```

---

## P1-A5: Photo Cache — Force UI Refresh After Change

**Problem:** Photo changes say "updated" but UI shows old image until full restart.

**Fix:**
1. After successful photo upload, clear Flutter's image cache
2. Add cache-buster query param to image URL
3. Invalidate the dog profile provider to force rebuild

```dart
void _onPhotoUpdated(String profileId) {
  imageCache.clear();
  PaintingBinding.instance.imageCache.clear();
  ref.invalidate(dogProfilesProvider);
  setState(() {});
}
```

---

## P2-A6: "Waiting for Dog" Overlay Size

**Problem:** Too large, covers whole screen.

**Fix:** Reduce by 60%. Small status indicator, not full-screen takeover.

---

## P2-A7: Scheduler UI — Send to Robot, Not Relay

**Problem:** Schedule CRUD needs to go to robot, not relay. Robot stores schedules locally for offline execution.

**Fix:**
1. Schedule creation sends WebSocket command to robot:
```json
{
  "type": "command",
  "command": "create_schedule",
  "data": {
    "mission_name": "sit_training",
    "dog_id": "dog_xxx",
    "type": "daily",
    "start_time": "08:00",
    "days_of_week": [1,2,3,4,5],
    "enabled": true
  }
}
```
2. Fetch schedules from robot: send `get_schedules` command, listen for response event
3. Display schedule list from robot response
4. Delete/update schedules via robot commands

---

## WHY THIS MATTERS — The Cascade

The ghost commands create a chain reaction that makes EVERYTHING look broken:

```
App sends stop_mission on screen navigation
  └→ Mission stops after 58 seconds
     └→ Dog never got a chance to perform trick
        └→ "Mission doesn't do anything"

Video overlay shows IDLE during MISSION (robot bug, but...)
  └→ User thinks mission didn't start
     └→ User navigates away to try again
        └→ App sends stop_mission (ghost command)
           └→ Mission actually stops
              └→ "See? It doesn't work"
```

The robot AI is fine. The missions can work. But the app is killing them behind the user's back. Fix P0-A1 first and half the other problems disappear.

---

## Test Checklist

- [ ] Start mission → navigate to home → navigate to drive → come back → mission STILL RUNNING
- [ ] Start coach → press back → NO duplicate commands in relay logs (zero stop_coach or set_mode)
- [ ] Mode display matches robot state, never flips on its own
- [ ] Start mission → spinner → waits for robot confirmation → then shows mission UI
- [ ] MP3 upload via HTTP completes without WebSocket disconnect
- [ ] Change dog photo → immediately visible without restart
