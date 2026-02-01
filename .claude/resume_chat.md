# WIM-Z Resume Chat Log

## Session: 2026-02-01 (Build 37.1 - APP)
**Goal:** Fix mode cycling, mode mismatch, upload timeout, scheduler errors, duplicate commands
**Status:** ✅ Complete (APP portion)

### Issues Addressed:

| # | Issue | Root Cause | Fix |
|---|-------|------------|-----|
| 1 | Manual mode cycles idle→manual→idle | Telemetry sync (2s) overriding user click | Added 2s user-initiated cooldown that blocks ALL external mode updates |
| 2 | Scheduler "failed to create schedule" | RELAY doesn't implement endpoint | Added specific error messages (404→"not supported", 501→"not implemented") |
| 3 | MP3 upload no feedback | RELAY doesn't send upload_complete event | Added 10s timeout with "may have failed" warning |
| 4 | App says "Sit Training" but video says "idle" | Mode locked on ANY progress event | Now only locks mode on explicit `action: 'started'` event |
| 5 | Duplicate stop_coach/set_mode commands | Back button AND PopScope both calling stopCoaching() | Removed call from back button, let PopScope handle it |

### Log Analysis (see `.claude/WHY37BUILD_SUCKS.md` for full details):

**MP3 Upload (02:54):** ROBOT disconnected when receiving 5MB WebSocket message - **ROBOT issue**
**Mission mode "idle" overlay:** Robot's video_track.py not reading mode correctly - **ROBOT issue**
**No bounding boxes:** Robot not drawing boxes on video frames - **ROBOT issue**
**Scheduler disappears:** RELAY doesn't implement /schedules endpoints - **RELAY issue**

### Key Files Modified:

| File | Changes |
|------|---------|
| `lib/domain/providers/mode_provider.dart` | Added `_userInitiatedChangeTime` + 2s cooldown; fixed mode locking to require explicit 'started' action |
| `lib/presentation/widgets/controls/quick_actions.dart` | Added `_uploadTimeoutTimer` (10s) with warning message |
| `lib/data/datasources/robot_api.dart` | Added specific error messages for schedule creation (404, 501, 503, 401) |
| `lib/domain/providers/scheduler_provider.dart` | Show specific error from API instead of generic message |
| `lib/presentation/screens/scheduler/schedule_edit_screen.dart` | Display error from scheduler state |
| `lib/presentation/screens/coach/coach_screen.dart` | Removed duplicate stopCoaching() call from back button |
| `.claude/WHY37BUILD_SUCKS.md` | **NEW** Comprehensive analysis of all Build 37 issues

### Technical Details:

1. **User-Initiated Mode Change Cooldown:**
   - When user clicks mode selector, `_userInitiatedChangeTime` is set
   - For 2 seconds, ALL external mode updates are blocked:
     - `_syncFromTelemetry()` returns early
     - `_handleModeConfirmation()` only accepts the expected mode
   - Prevents telemetry sync and stray events from cycling the mode

2. **Conservative Mode Locking:**
   - Previously: ANY `mission_progress` event would set mode to "mission"
   - Now: Only `action: 'started'` event locks mode
   - Progress events without 'started' only update mission info if ALREADY in mission mode

3. **Upload Timeout:**
   - 10-second timer starts after `sendUploadSong()`
   - Cancelled if `upload_complete`/`upload_error` event received
   - Shows orange warning "Upload may have failed - no response from server"

4. **Scheduler Error Messages:**
   - 404 → "Scheduling not supported by server"
   - 501 → "Scheduling feature not implemented"
   - 503 → "Robot offline - cannot create schedule"
   - 401/403 → "Not authorized to create schedules"

### Still Needs RELAY:
- `/schedules` REST endpoints (POST, PUT, DELETE)
- `/schedules/enable` and `/schedules/disable` endpoints
- Forward `upload_complete`/`upload_error` events from robot
- These will continue to fail until RELAY implements them

### Still Needs ROBOT:
- Send `upload_complete` event after processing `upload_song` command
- Actually start missions when `start_mission` command received
- Send `mission_progress` with `action: 'started'` when mission begins

---

## Session: 2026-01-31 (Build 34 - APP)
**Goal:** Fix APP-side issues from Build 33 testing session
**Status:** ✅ Complete (APP portion)

### APP CLAUDE Tasks Completed:

| Priority | Issue | Fix |
|----------|-------|-----|
| **P0** | Mission UI doesn't reflect robot state | Added 3s verification timer; shows "Mission failed to start" if no progress received |
| **P0** | Mode display rapid flipping | Added 500ms debounce to mode changes; tracks lastModeChangeTime |
| **P1** | MP3 upload causing disconnect | File read now in isolate via `compute()`; 10MB size limit; better error handling |
| **P1** | Photo cache not clearing | Added `PaintingBinding.instance.imageCache.clear()` on photo change |
| **P2** | "Waiting for robot" flash | Added 1.5s grace period before downgrading from robotOnline to relayConnected |
| **P2** | Scheduler save no feedback | Added success/error snackbars when save completes or fails |

### Key Files Modified:

| File | Changes |
|------|---------|
| `lib/domain/providers/missions_provider.dart` | Added `_startVerificationTimer` for mission start verification |
| `lib/domain/providers/mode_provider.dart` | Added `_modeChangeDebounce` (500ms) and `_lastModeChangeTime` tracking |
| `lib/domain/providers/connection_provider.dart` | Added `_statusDowngradeDelay` (1.5s) grace period before showing "Waiting for robot" |
| `lib/presentation/widgets/controls/quick_actions.dart` | MP3 upload uses isolate; added 10MB size limit; improved error handling |
| `lib/presentation/screens/dog_profile/dog_profile_screen.dart` | Clear `imageCache` on photo update |
| `lib/presentation/screens/scheduler/schedule_edit_screen.dart` | Added success/error snackbars for save |
| `lib/presentation/widgets/mission/mission_progress_overlay.dart` | Reduced overlay size by ~40% (200px → 140px) |

### Technical Details:

1. **Mission Verification Timer:**
   - Starts on `startMission()`
   - Cancelled on `mission_progress`, `mission_complete`, or `mission_stopped` events
   - After 3s with no real progress, shows error and clears mission state

2. **Mode Debouncing:**
   - Ignores mode changes within 500ms of last change (unless waiting for pending mode)
   - All mode-changing paths now track `_lastModeChangeTime`

3. **MP3 Upload Fix:**
   - `compute(_readFileBytes, path)` reads file in isolate
   - `compute(base64Encode, bytes)` encodes in isolate
   - Shows "Reading..." indicator during file processing
   - Catches send errors separately to preserve connection

4. **Connection Status Debouncing:**
   - When robot goes offline, starts 1.5s timer before showing "Waiting for robot"
   - If robot comes back online during grace period, timer cancelled
   - Prevents brief status flashes during momentary disconnects

### Remaining for ROBOT CLAUDE:
- Mission execution pipeline (missions don't run)
- AI detection regression (wrong dog labeled)
- Servo control (too fast, jerky)
- Mode state sync (events not being sent)
- Video overlay "????" characters
- **NEW: Send `upload_complete` or `upload_error` event after receiving `upload_song` command**
  - APP now listens for these events to show success/failure feedback

### Remaining for RELAY CLAUDE:
- Connection stability (timeouts during uploads)
- Event forwarding verification
- **NEW: Implement `/missions/schedule` REST endpoints** (currently returns error)
  - POST `/missions/schedule` - create schedule
  - PUT `/missions/schedule/:id` - update schedule
  - DELETE `/missions/schedule/:id` - delete schedule
  - POST `/missions/schedule/enable` - enable scheduling
  - POST `/missions/schedule/disable` - disable scheduling
- **NEW: Forward `upload_complete`/`upload_error` events from robot to app**

---

## Session: 2026-01-31 (Build 33)
**Goal:** Implement Scheduler UI (Step 5 of Training Features)
**Status:** ✅ Complete

### Work Completed:
1. **MissionSchedule Model** (`lib/data/models/schedule.dart`)
   - ScheduleType enum (once, daily, weekly)
   - Freezed class with hour, minute, weekdays, enabled, nextRun
   - Helper methods for time formatting and schedule descriptions

2. **Schedule API** (`lib/data/datasources/robot_api.dart`)
   - getSchedules(), createSchedule(), updateSchedule(), deleteSchedule()
   - enableScheduling(), disableScheduling() for master toggle

3. **SchedulerProvider** (`lib/domain/providers/scheduler_provider.dart`)
   - Full CRUD with optimistic updates
   - Global enable/disable toggle
   - Sorted schedules provider

4. **Scheduler Screens**
   - SchedulerScreen: List view with master toggle, swipe-to-delete
   - ScheduleEditScreen: Dog/mission dropdowns, time picker, weekday selector

5. **Integration**
   - Added routes: /scheduler, /scheduler/new, /scheduler/:id
   - Settings → Training Scheduler link

### Key Files:
| File | Purpose |
|------|---------|
| `lib/data/models/schedule.dart` | MissionSchedule Freezed model |
| `lib/domain/providers/scheduler_provider.dart` | State + API calls |
| `lib/presentation/screens/scheduler/scheduler_screen.dart` | List screen |
| `lib/presentation/screens/scheduler/schedule_edit_screen.dart` | Create/edit |

### Commit: 635aff2 - feat: Build 33 — Programs, Coach Mode, History & Scheduler UI

### All Build 33 Features (Steps 1-5):
- ✅ Step 1: Dynamic Mission List
- ✅ Step 2: Programs
- ✅ Step 3: Coach Mode
- ✅ Step 4: History & Analytics
- ✅ Step 5: Training Scheduler UI

### Next Session:
1. Test scheduler on physical device
2. Verify robot endpoints work with app
3. Live testing of schedule creation flow

---

## Session: 2026-01-30 (Build 31 - Part 2)
**Goal:** Add command debouncing, timestamps, and audio_state sync
**Status:** ✅ Complete

### Problems Solved This Session:

1. **Command Queue Buildup on Reconnect**
   - **Problem:** Button mashing while robot busy caused commands to queue in relay, then all execute on reconnect (music plays, treats dispense, etc.)
   - **Root Cause:** No debouncing on quick action buttons, relay buffers commands
   - **Fix:** Added debouncing to all quick action controls + timestamps on all commands

2. **Music Player State Out of Sync**
   - **Problem:** App guessed play/pause state locally, got out of sync with robot
   - **Fix:** Added `audio_state` WebSocket event handler to sync from robot

3. **Investigated /audio/next Mystery**
   - **Finding:** Robot translates WebSocket `audio_next` → REST `/audio/next` internally
   - **Conclusion:** App did send the command, likely accidental button tap (buttons close together)

### Key Code Changes Made:

| File | Change |
|------|--------|
| `websocket_client.dart` | Added `timestamp` to all commands, added `audio_state` event handler |
| `control_provider.dart` | Debounced audio (300ms), treat (1s), LED (200ms) controls |
| `quick_actions.dart` | Debounced voice buttons (500ms), audio_state subscription, track name display |

### Debounce Values:
- Audio next/prev/toggle: 300ms
- Treat dispense: 1000ms (prevent overfeeding)
- LED pattern: 200ms
- Voice buttons (Good/Call/Treat/No): 500ms

### Commits This Session:
- `3ac53e4` - fix: Add command debouncing and timestamps to prevent queue buildup

### Robot/Relay TODO:
```python
# Reject stale commands (>2s old)
age_ms = time.time() * 1000 - cmd.get('timestamp', 0)
if age_ms > 2000:
    logger.info(f"Dropping stale: {cmd['command']} ({age_ms:.0f}ms)")
    return
```

### Next Session:
1. Test debouncing prevents queue buildup
2. Verify audio_state sync works with robot
3. Implement stale command rejection on robot/relay side

---

## Session: 2026-01-30 (Build 31)
**Goal:** Build 31 — Mission progress overlay, mode locking, coach-style flow display
**Status:** ✅ Complete

### What Changed (from BUILD31_APP_INSTRUCTIONS.md):

1. **Mission Progress Display (Priority 1 - DONE)**
   - Created `MissionProgressOverlay` widget with circular pie progress
   - Shows real-time status: waiting_for_dog, greeting, command, watching, success, failed, retry, completed
   - Stage indicator ("Stage 2 of 5")
   - Dog name + rewards count
   - Animated icons for each status
   - Overlay appears on video stream during active mission

2. **Mode Locking (Priority 2 - DONE)**
   - Mode selector shows lock icon when mission is active
   - Tooltip shows lock reason
   - Mode cannot be changed during active mission
   - Handles `mode_changed` WebSocket events with `locked` field

3. **Updated Mission Model**
   - Added `MissionStatus` enum with all coach-flow states
   - Added `stageNumber`, `totalStages`, `dogName` fields to `MissionProgress`
   - New `statusDisplay`, `stageDisplay` getters for UI
   - `effectiveProgress` for watching state (progress/target_sec)

4. **Updated Missions Provider**
   - Stores full `MissionProgress` object in state
   - Tracks status, stage, dogName, trick
   - Shows completion state for 3s before clearing

5. **Fixed Photo Change Bug**
   - `_changePhoto()` was popping bottom sheet before async operations
   - Now captures `profileId`, `notifier`, `messenger` upfront
   - Uses dialog instead of nested bottom sheet
   - Added extensive `[PHOTO]` logging

6. **Enhanced Upload Logging**
   - Added `[UPLOAD]` logs for MP3 file picker flow
   - Logs filename, size, base64 length, WebSocket command

### Key Code Changes Made:

#### New Files:
- `lib/presentation/widgets/mission/mission_progress_overlay.dart` — Circular pie progress overlay

#### Modified Files:
- `lib/data/models/mission.dart` — Added `MissionStatus` enum, new fields
- `lib/domain/providers/missions_provider.dart` — Full progress state tracking
- `lib/domain/providers/mode_provider.dart` — Handle `mode_changed` events with locked
- `lib/core/network/websocket_client.dart` — Handle `mode_changed` event type
- `lib/presentation/screens/home/home_screen.dart` — Add overlay, mode lock UI
- `lib/presentation/screens/missions/missions_screen.dart` — Use Build 31 status fields
- `lib/presentation/screens/dog_profile/dog_profile_screen.dart` — Fix photo change flow
- `lib/presentation/widgets/controls/quick_actions.dart` — Enhanced upload logging
- `lib/domain/providers/dog_profiles_provider.dart` — Photo update logging
- `pubspec.yaml` — Version bump to 1.0.0+31

### Architecture Notes:
- `MissionProgressOverlay` is a positioned overlay on the video stack
- Uses `missionsProvider` for state, renders based on `activeStatus`
- Mode selector returns non-interactive widget when `isModeLocked`
- `_handleModeChangedEvent()` extracts mission name from lock_reason

### WebSocket Events Handled:
- `mission_progress` — Updates stage, status, progress, dogName, rewards
- `mission_complete` — Shows completion state, clears after 3s
- `mission_stopped` — Clears immediately
- `mode_changed` — Updates mode and locked state

### Testing Checklist:
- [ ] Start mission → see "Waiting for dog" status
- [ ] Dog appears → status changes to "greeting" then "command"
- [ ] During "watching" → circular progress shows and fills
- [ ] Trick success → green checkmark appears
- [ ] Mission complete → summary shows briefly
- [ ] Mode selector shows lock icon during active mission
- [ ] Stop button works mid-mission
- [ ] Photo change saves correctly
- [ ] Upload shows detailed logs

---

## Session: 2026-01-29 (Build 29)
**Goal:** Build 29 — Fix mode sync, voice dog_id, profile issues, motor trim, logout, remove connect screen
**Status:** ✅ Complete

### Problems Solved This Session:

1. **Mode State Not Updating in UI**
   - **Problem:** Robot sends `status_update` and `mission_progress` events but UI shows wrong mode (e.g., "Manual" when in "Mission")
   - **Fix:** Added explicit `mission_progress/complete/stopped` handlers in `websocket_client.dart`
   - Added periodic telemetry sync (every 2s) in `mode_provider.dart` to catch missed WebSocket events
   - New `_startTelemetrySync()` and `_syncFromTelemetry()` methods

2. **Voice Commands Missing dog_id**
   - **Problem:** Logs showed `play_voice, params: {'voice_type': 'no'}` with no dog_id
   - **Fix:** Now require selected dog before sending voice commands
   - Show "Please select a dog first" error if no dog selected
   - Changed `call_dog` to pass dog info directly via `ws.sendCallDog()` instead of through provider

3. **Dog Profile Issues**
   - **Voice button blank screen:** Changed to use `/voice-setup` route with extra data instead of nested route
   - **Photo doesn't save:** Now copies photo to permanent location (`dog_photos/` in app documents) before saving path
   - **Breed dialog issues:** Fixed context handling — don't pop bottom sheet before dialog, capture references upfront

4. **Motor Trim Needs 50%**
   - **Problem:** Trim range was only -20% to +20%
   - **Fix:** Changed to -50% to +50% in `settings_provider.dart` and slider UI

5. **Sign Out Clears All Dogs**
   - **Problem:** `logout()` called `clearState()` on dog profiles, wiping local data
   - **Fix:** Removed dog profile clearing from logout — dogs persist locally regardless of auth

6. **Two Login Screens**
   - **Problem:** `/connect` screen was redundant since login handles everything
   - **Fix:** Removed `/connect` route and deleted `connect_screen.dart`

### Key Code Changes Made:

#### Modified Files:
- `lib/core/network/websocket_client.dart` — Explicit mission event handlers
- `lib/domain/providers/mode_provider.dart` — Periodic telemetry sync
- `lib/domain/providers/auth_provider.dart` — Don't clear dogs on logout
- `lib/domain/providers/settings_provider.dart` — Motor trim 50%
- `lib/presentation/widgets/controls/quick_actions.dart` — Require selected dog for voice commands
- `lib/presentation/screens/dog_profile/dog_profile_screen.dart` — Photo saving, dialog fixes, voice route
- `lib/presentation/screens/settings/settings_screen.dart` — Slider range 50%
- `lib/app.dart` — Remove connect route
- `pubspec.yaml` — Version bump

#### Deleted Files:
- `lib/presentation/screens/connect/connect_screen.dart`

### Commits This Session:
- `c1151f6` - fix: Build 29 — mode sync, voice dog_id, profile fixes, motor trim, logout

### Architecture Notes:
- `_telemetrySyncTimer` in ModeStateNotifier runs every 2s to sync mode from telemetry
- Photo files saved to `getApplicationDocumentsDirectory()/dog_photos/<dogId>.jpg`
- Dog profiles no longer cleared on logout — only missions state is cleared
- Voice commands require `selectedDog != null` before sending

### Next Session:
1. Test mode sync with physical robot during missions
2. Verify photo persistence across app restarts
3. Test voice commands show error when no dog selected
4. Verify breed saves and displays correctly
5. Test logout preserves dogs

### Important Notes/Warnings:
- Run `dart run build_runner build --delete-conflicting-outputs` after provider changes
- Motor trim range increased — existing saved values still valid (clamped on load)

---

## Session: 2026-01-29 (Build 28)
**Goal:** Build 28 — Fix mission mode conflicts, upload crash, breed field, unified login
**Status:** ✅ Complete

### Problems Solved This Session:

1. **P0: Mode Lock for Missions**
   - **Problem:** Drive screen was overriding mode to "manual" even when mission active
   - **Fix:** Added `activeMissionId`, `activeMissionName`, `isModeLocked` to `ModeState`
   - Added `_handleMissionProgress()` to listen for `mission_progress` events
   - Mode automatically sets to `mission` when `action: 'started'`, clears on `completed`/`stopped`
   - `setMode()` blocks changes when `isModeLocked` is true
   - Drive screen respects mode lock — won't override to manual during missions

2. **P1: Upload Crash (iOS)**
   - **Problem:** `FileType.audio` opens Apple Music library and crashes on iOS
   - **Fix:** Changed to `FileType.custom` with `allowedExtensions: ['mp3']`
   - Added `PlatformException` handling and debug logging

3. **P1: Breed Field Missing**
   - **Problem:** Add Dog screen had no breed field
   - **Fix:** Added `_breedController` and breed TextFormField to name step
   - Breed now included in `DogProfile` creation

4. **P2: Unified Login Flow**
   - **Problem:** Two screens (Login → Connect) both asking for server info was confusing
   - **Fix:** Login screen now connects WebSocket AND navigates directly to `/home`
   - Removed redirect to `/connect` from home screen on disconnect
   - Users stay in app — MainShell's reconnect banner handles reconnection
   - "Disconnect" in Settings goes to `/login` (explicit user action)

### Commits This Session:
- `9c26203` - fix: Build 28 — mode lock for missions, upload crash, breed field, unified login

---

## Session: 2026-01-26
**Goal:** Fix WebRTC session churn on background + mode change timeout false positives
**Status:** Complete

### Problems Solved This Session:

1. **WebRTC Session Churn on Background (PRIORITY 1)**
   - **Problem:** When screen turns off, app rapidly creates/closes WebRTC sessions (5 sessions in 14 seconds), then disconnects. No app lifecycle handling existed.
   - **Fix:** Added `_isPaused` flag and `pause()`/`resume()` methods to `WebRTCNotifier`
   - When backgrounded: closes WebRTC cleanly, cancels reconnect timers, suppresses all reconnection attempts
   - When resumed: reconnects to last device if one existed
   - Guarded 4 reconnection paths: `_scheduleReconnect()`, reconnect timer callback, device status listener, webrtc close listener
   - Added `WidgetsBindingObserver` to `WimzApp` to trigger pause/resume on lifecycle changes

2. **Mode Change Timeout False Positives (LOWER PRIORITY)**
   - **Problem:** App shows "mode change timed out" even when mode changes successfully
   - **Fix:** Updated `_onTimeout()` to check latest telemetry mode before showing error
   - If telemetry shows mode matches pending mode, treats it as silent confirmation (no error shown)
   - Only shows "Mode change timed out" if mode genuinely didn't change

### Commits This Session:
- `58d531d` - fix: Prevent WebRTC session churn on background, fix mode timeout false positives

---

## Session: 2026-01-24
**Goal:** Fix device switching, add optimistic mode UI, consolidate settings
**Status:** Complete

### Problems Solved This Session:

1. **Optimistic Mode Changes**
   - Created `ModeState` class with `currentMode`, `pendingMode`, `isChanging`, `error`
   - Implemented 5-second timeout that reverts to previous mode on failure
   - Mode selector shows loading spinner while changing
   - Error snackbar displayed on timeout/failure
   - Listens to `status_update`, `battery`, `mode` events for confirmation

2. **status_update Event Handler**
   - Added `status_update` case to `websocket_client.dart:213-219`
   - Added `status_update` case to `telemetry_provider.dart:44`
   - Mode provider listens for mode in status_update, battery, telemetry events

3. **Settings UI Consolidation**
   - Rewrote settings_screen.dart with 2 main sections:
     - Connection Status: "Connected to X" or "Not connected" with disconnect
     - Manage Devices: Inline list with online indicators, swipe-to-unpair, tap to connect
   - Removed redundant connection details
   - Added WiFi setup help expandable section

### Commits This Session:
- `15afac8` - feat: Optimistic mode UI, status_update handler, settings consolidation

---

## Session: 2026-01-21
**Goal:** Fix WebRTC video streaming and debug robot communication
**Status:** Partial - App side complete, robot-side issues remain

### Problems Solved This Session:

1. **WebRTC Provider Architecture**
   - Rewrote `webrtc_provider.dart` as StateNotifierProvider for singleton state
   - Consolidated signaling flow: webrtc_request → credentials → offer → answer → ICE
   - Removed duplicate files: `webrtc_service.dart`, `webrtc_handler.dart`

2. **ice_servers Type Casting Error**
   - Fixed: `type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>'`
   - Relay sends ice_servers as List, not wrapped Map
   - Added type check: `iceServers is List ? {'iceServers': iceServers} : iceServers`

---

## Session: 2026-01-20
**Goal:** Update relay connection URLs to production server
**Status:** Complete

### Configuration Now Active:
- REST API: https://api.wimzai.com
- WebSocket: wss://api.wimzai.com/ws/app
- Cloud mode: Telemetry via WebSocket only (no REST polling)

### GitHub:
- Repository: https://github.com/lolygagv2/dogbot-app
- Ready for Codemagic CI/CD
