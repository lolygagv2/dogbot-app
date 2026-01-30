# WIM-Z Resume Chat Log

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
