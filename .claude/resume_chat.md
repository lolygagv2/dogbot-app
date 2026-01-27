# WIM-Z Resume Chat Log

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

4. **Command Audit for device_id**
   - Verified all `ws.send()` calls include `device_id` where needed
   - WebRTC signaling uses session-based routing (correct)
   - All device-routed commands properly include device_id

5. **Debug Logging for Device Selection**
   - Added logging to `paired_devices_provider.dart` for device selection flow
   - Logs device ID, online status map, and completion

### Key Code Changes Made:

#### Modified Files:
- `lib/domain/providers/mode_provider.dart` - Complete rewrite with optimistic updates
  - New: ModeState, ModeStateNotifier, displayModeProvider, modeErrorProvider
  - 5-second timeout with revert on failure
  - WebSocket event listener for confirmations
- `lib/core/network/websocket_client.dart` - Added status_update handler
- `lib/domain/providers/telemetry_provider.dart` - Added status_update case
- `lib/domain/providers/paired_devices_provider.dart` - Added debug logging
- `lib/presentation/screens/home/home_screen.dart` - Updated _ModeSelector for optimistic UI
- `lib/presentation/screens/settings/settings_screen.dart` - Complete UI consolidation

### Commits This Session:
- `15afac8` - feat: Optimistic mode UI, status_update handler, settings consolidation

### Working Features:
- Optimistic mode changes with timeout/revert
- status_update event processing
- Consolidated settings with device management
- Device switching with proper video reconnection
- 3-tier connection status (disconnected/relayConnected/robotOnline)

### Architecture Notes:
- `displayModeProvider` returns pending mode for immediate UI feedback
- `modeErrorProvider` for toast display (auto-clears after 5 seconds)
- Legacy `modeControlProvider` delegates to new `modeStateProvider.notifier`

### Next Session:
1. Test optimistic mode on physical device
2. Verify status_update events from robot trigger confirmations
3. Debug any remaining robot offline display issues

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

3. **Command Debug Logging**
   - Added `WS SEND: $json` logging to websocket_client.dart
   - Traced all commands being sent correctly

4. **Servo Pan Inversion**
   - Fixed joystick left/right being backwards for camera pan
   - Negated pan value in pan_tilt_control.dart

### Key Code Changes Made:

#### Deleted Files:
- `lib/data/services/webrtc_service.dart` (replaced by provider)
- `lib/domain/providers/webrtc_handler.dart` (merged into webrtc_provider)

#### Modified Files:
- `lib/domain/providers/webrtc_provider.dart` - Complete rewrite as StateNotifierProvider
- `lib/core/network/websocket_client.dart` - Added debug logging
- `lib/presentation/widgets/video/webrtc_video_view.dart` - Updated for new provider
- `lib/presentation/widgets/controls/pan_tilt_control.dart` - Pan inversion fix
- `lib/presentation/screens/home/home_screen.dart` - Removed old imports
- `lib/presentation/screens/drive/drive_screen.dart` - Updated WebRTCVideoView usage

### Working Features (Confirmed):
- LED commands (rainbow, celebration patterns)
- Audio commands (good_dog.mp3)
- Treat dispenser
- Servo control (pan/tilt) - now with correct direction

### Unresolved Issues (Robot-Side):

1. **Motor Control Not Responding**
   - App sends correct: `{"type":"command","command":"motor","data":{"left":0.48,"right":0.04}}`
   - Robot not executing - check robot's motor command handler

2. **WebRTC Video Not Displaying**
   - App logs: "Peer connection created, waiting for offer"
   - Robot needs to send `webrtc_offer` after receiving `webrtc_request`

### Robot-Side Fix Made (by user):
- Changed `message.get('params', {})` → `message.get('data', {})` in RelayClient
- This fixed LED, audio, treat, servo - but motor still not working

### Next Session:
1. Debug robot's motor command handler specifically
2. Ensure robot sends WebRTC offer for video
3. Remove debug logging once testing complete

### Important Notes:
- Default device ID: `wimz_robot_01`
- Command format: `{"type":"command","command":"<cmd>","data":{...}}`
- WebRTC signaling via WebSocket, not separate service

---

## Session: 2026-01-20
**Goal:** Update relay connection URLs to production server
**Status:** Complete

### Problems Solved This Session:

1. **Production URL Configuration**
   - Changed API URL from api.wimz.io → api.wimzai.com
   - Changed WebSocket path from /ws → /ws/app
   - Set default environment to Environment.prod

2. **Cloud Mode Telemetry**
   - Disabled REST polling to /telemetry in production mode
   - Telemetry now received via WebSocket events from relay
   - Robot → Relay → App flow implemented

3. **Build Environment**
   - Added Linux platform support for desktop testing
   - Installed build tools (clang, ninja, lld, pkg-config)

### Key Code Changes Made:

#### Modified Files:
- `lib/core/config/environment.dart` - Production URLs, default env
- `lib/core/network/dio_client.dart` - Default base URL initialization
- `lib/domain/providers/telemetry_provider.dart` - WebSocket-only telemetry in cloud mode

### Configuration Now Active:
- REST API: https://api.wimzai.com
- WebSocket: wss://api.wimzai.com/ws/app
- Cloud mode: Telemetry via WebSocket only (no REST polling)

### Commits:
- `dd0e41d` - feat: Update to production relay server
- `5d2599e` - feat: Add dog profiles, notifications, and Linux platform

### GitHub:
- Repository: https://github.com/lolygagv2/dogbot-app
- Ready for Codemagic CI/CD

---
