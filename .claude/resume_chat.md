# WIM-Z Resume Chat Log

## Session: 2026-01-29
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

### Key Code Changes Made:

#### Modified Files:
- `lib/domain/providers/mode_provider.dart` — Mission mode lock, event handling, new providers
- `lib/presentation/screens/auth/login_screen.dart` — Unified login + connect flow
- `lib/presentation/screens/dog_profile/add_dog_screen.dart` — Breed field
- `lib/presentation/screens/drive/drive_screen.dart` — Respect mode lock
- `lib/presentation/screens/home/home_screen.dart` — Remove disconnect redirect
- `lib/presentation/screens/settings/settings_screen.dart` — Disconnect → login
- `lib/presentation/widgets/controls/quick_actions.dart` — Fix upload crash

### Commits This Session:
- `9c26203` - fix: Build 28 — mode lock for missions, upload crash, breed field, unified login

### Architecture Notes:
- `ModeState.isModeLocked` prevents mode changes during active missions
- `mission_progress` event with `action: 'started'` triggers lock
- `mission_complete` or `mission_stopped` releases lock
- New providers: `isMissionActiveProvider`, `activeMissionNameProvider`
- Login flow: authenticate → connect WebSocket → go to /home (one step)

### Next Session:
1. Test mission mode lock on physical device with robot
2. Verify upload works on iOS after FileType.custom change
3. Test breed field saves and displays correctly
4. Verify reconnect banner works smoothly after connection drop

### Important Notes/Warnings:
- Run `dart run build_runner build --delete-conflicting-outputs` after provider changes
- The `/connect` route still exists as fallback but not part of main flow
- WebRTC provider already handles pause/resume on app lifecycle (previous session)

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

### Key Code Changes Made:

#### Modified Files:
- `lib/domain/providers/webrtc_provider.dart` - Added `_isPaused`, `pause()`, `resume()`, guarded all reconnection paths
- `lib/app.dart` - Converted `WimzApp` to `ConsumerStatefulWidget` with `WidgetsBindingObserver` for lifecycle management
- `lib/domain/providers/mode_provider.dart` - Updated `_onTimeout()` to check telemetry before showing error
- `pubspec.yaml` - Version bump to 1.0.0+21

### Commits This Session:
- `58d531d` - fix: Prevent WebRTC session churn on background, fix mode timeout false positives

### Architecture Notes:
- `WimzApp` is now a `ConsumerStatefulWidget` with `WidgetsBindingObserver` mixin (was `ConsumerWidget`)
- `AppLifecycleState.paused`/`inactive` → `webrtcProvider.pause()` (close + suppress reconnects)
- `AppLifecycleState.resumed` → `webrtcProvider.resume()` (reconnect to last device)
- `_lastDeviceId` preserved across pause/resume cycle for seamless reconnection
- Mode timeout confirmation timeout remains 10 seconds

### Next Session:
1. Test WebRTC pause/resume on physical device (screen off/on cycle)
2. Verify no more session churn in logs when backgrounded
3. Test mode changes with robot to confirm timeout fix works
4. Consider adding WebSocket pause/resume if needed (currently WebSocket stays alive in background - intentional for receiving events)

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

### Commits This Session:
- WebRTC architecture rewrite

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
