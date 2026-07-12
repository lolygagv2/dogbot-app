# WIM-Z Mobile App - Project Directory Structure
*Last Updated: 2026-05-25 - Flutter Mobile App*

## ⚠️ IMPORTANT NOTES
This is the **Flutter mobile app** that connects to the WIM-Z robot via a server.
Architecture: Mobile App (this repo) → Server (intermediary) → Robot (Pi 5)

## 📁 Active Project Structure

```
/home/morgan/wimzapp/   # WIM-Z Flutter Mobile App

   📂 .claude/                    # Claude AI session management
      CLAUDE.md                   # Development rules (DO NOT DELETE)
      CLAUDE_CODE_GUIDE.md        # Detailed implementation guide
      DEVELOPMENT_PROTOCOL.md     # Development workflow rules
      WIM-Z_Project_Directory_Structure.md  # THIS FILE
      resume_chat.md              # Session history
      product_roadmap.md          # WIM-Z project phases
      development_todos.md        # Priority tasks
      commands/                   # Session commands
          session_start.md        # Session initialization
          session_end.md          # Session cleanup
          safe-cleanup.md         # Cleanup protocol
          PIDref.md               # PID reference (for robot)

   📂 lib/                         # Flutter app source code
      main.dart                    App entry point
      app.dart                     MaterialApp + GoRouter routing

      📂 core/                     # Shared infrastructure
         📂 config/
            environment.dart       Dev/prod configuration
         📂 constants/
            api_endpoints.dart     API endpoint paths
            app_constants.dart     Timeouts, defaults, UI constants
         📂 network/
            dio_client.dart        HTTP client (Singleton)
            websocket_client.dart  WebSocket: handshake gate, close-code retry, heartbeat
         📂 utils/
            conn_trace.dart        🆕 connTrace() + ConnTraceLog ring buffer (WebRTC signaling trace)
            time_utils.dart        🆕 Build 139 — parseServerTimestamp: naive relay/robot ISO strings are UTC → device-local (Dart parses naive as local!)

      📂 data/                     # Data layer
         📂 models/                # Freezed data classes (and plain immutables)
            telemetry.dart         Robot status model
            mission.dart           Training mission config
            night_mode_state.dart  🆕 day/night camera state + override enums (Build 99)
            spec_records.dart      🆕 Build 135 — SpecEvent/SessionReport/MediaAsset, field-for-field mirrors of WIMZ_Data_Architecture_Spec tables
         📂 stub/
            spec_stub_data.dart    🆕 Build 135 — SAMPLE rows for UI previews ONLY (never feed live providers)
         📂 datasources/
            robot_api.dart         REST API client for WIM-Z
         📂 services/
            photo_service.dart     Photo capture → gallery save
            video_service.dart     Video capture → gallery save (Build 59)

      📂 domain/                   # Business logic
         📂 providers/             # Riverpod state management
            connection_provider.dart    Connection state
            telemetry_provider.dart     Robot status updates (incl. volume)
            control_provider.dart       Motor, servo, treat, LED, audio
            video_quality_provider.dart robot adaptive-bitrate state + override
            volume_provider.dart        system volume — reconciles to telemetry
            night_mode_provider.dart    🆕 day/night state + override; 90s heartbeat-stale (Build 99)

      📂 presentation/             # UI layer
         📂 screens/
            connect/               Initial connection screen
            home/                  Dashboard with video + status
            drive/                 Manual joystick control
            missions/              Training session management
            notifications/         Activity dashboard + event feed (Build 59)
            settings/              Configuration & info
                                   └ connection_diagnostics_screen.dart 🆕 on-device WebRTC trace viewer + LED ping (Build 135)
            dev/                   🆕 Build 135 — developer preview shells
               ui_previews.dart                    UiPreviewHubScreen + EventListView + SessionReportView (spec-shaped, stub-fed from hub only)
         📂 widgets/
            video/                 MJPEG viewer
                                   └ video_saved_sheet.dart 🆕 Build 135 — media_asset "video saved" confirmation (Chain REC shell)
            controls/              Joystick, pan/tilt, quick actions
            status/                Battery, connection, detection, treat counter
            common/                Loading, errors, shared UI
            night_mode/            🆕 Build 99 — day/night UI
               mode_badge.dart                     Drive-screen sun/moon badge (display-only)
               night_vision_settings_section.dart  Settings panel: mode + lux + override
            silent_guardian/
               intervention_level_section.dart     Renamed from punishment_level_section.dart (Build 135, A-WORDING)
         📂 theme/
            app_theme.dart         Dark theme with neon aesthetics

   📂 test/                        # All test files
      unit/                        Unit tests
      widget/                      Widget tests
      integration/                 Integration tests
      core/utils/time_utils_test.dart              🆕 Build 139 — UTC/naive/offset timestamp parsing (7 tests)
      domain/providers/dog_profiles_merge_test.dart 🆕 Build 139 — mergeRelayDogs + dedupeByName anti-replication (10 tests)

   📂 assets/                      # Static assets
      images/                      App images
      icons/                       Custom icons
      animations/                  Rive/Lottie animations
      fonts/                       Custom fonts

   📂 docs/                        # Documentation (DO NOT DELETE)
      *.md                         Reference docs

   # Config files (root)
   pubspec.yaml                    Dependencies and assets
   analysis_options.yaml           Linter rules
   README.md                       Project overview

```

## 📋 File Status Legend
- ✅ **ACTIVE** - Currently in use and working
- 🆕 **NEW** - Added in current session
- ⏳ **TODO** - Needs implementation
- ➡️ **MIGRATING** - Being moved/refactored
- ❌ **MISSING** - Required but not found
- 🔒 **PROTECTED** - Do not modify without permission
- ⚠️ **ISSUE** - Needs attention/cleanup

## 🔍 Key Files by Function

### **App Entry & Routing**
- `lib/main.dart` - App initialization, ProviderScope wrapper
- `lib/app.dart` - MaterialApp, GoRouter routes, theme

### **State Management (Riverpod)**
- `lib/domain/providers/connection_provider.dart` - Connection lifecycle
- `lib/domain/providers/telemetry_provider.dart` - Robot status polling + WebSocket
- `lib/domain/providers/control_provider.dart` - Motor, servo, treat, LED, audio

### **Networking**
- `lib/core/network/dio_client.dart` - HTTP client singleton with interceptors
- `lib/core/network/websocket_client.dart` - WebSocket with auto-reconnect
- `lib/data/datasources/robot_api.dart` - REST API methods for all endpoints

### **Data Models**
- `lib/data/models/telemetry.dart` - Robot status (Freezed)
- `lib/data/models/mission.dart` - Training mission config (Freezed)



## 📝 How Claude Finds Files

When answering questions about Flutter mobile app functionality:

1. **For "is X working?"** → Check test files in `test/`
2. **For "how does X work?"** → Check implementation in `lib/domain/providers/` or `lib/data/`
3. **For "app entry/routing"** → Check `lib/main.dart` and `lib/app.dart`
4. **For "API calls"** → Check `lib/data/datasources/robot_api.dart`
5. **For "real-time updates"** → Check `lib/core/network/websocket_client.dart`
6. **For "state management"** → Check `lib/domain/providers/`
7. **For "UI components"** → Check `lib/presentation/widgets/` and `lib/presentation/screens/`
8. **For "data models"** → Check `lib/data/models/` (Freezed classes)
9. **For "networking config"** → Check `lib/core/network/` and `lib/core/constants/`

## ✨ Session Additions (2026-05-25 cont. — Build 100)

### Routing refactor (no new files, but architecturally significant):
- **`lib/app.dart`** — `ShellRoute` → `StatefulShellRoute.indexedStack` so all 6 main-nav tabs stay mounted in an IndexedStack across navigation. Fixes the 1–5s black-screen on tab return to /home: the iOS `RTCVideoView` platform-view was being destroyed on every nav-away under the old `ShellRoute` and had to re-bind its native texture on return; now the widget tree persists. `MainShell` now accepts `StatefulNavigationShell` instead of `Widget child`; bottom-nav uses `navigationShell.goBranch(index)` instead of `context.go(path)`.
- `/programs` and `/programs/:id` are now co-located with `/missions` under the missions branch (StatefulShellBranch requires each tab's routes to be branch-local).

### Wire-contract corrections:
- **`lib/core/network/websocket_client.dart`** — `sendNightModeOverride()` now uses the standard `sendCommand()` relay envelope (was emitting a bare typed frame the relay couldn't route).
- **`lib/data/models/night_mode_state.dart`** — `fromJson` now parses `last_changed_at` as a Unix epoch float (the actual robot wire format), with ISO string fallback.

## ✨ Session Additions (2026-05-25 — Build 99)

### Night Vision (app-side):
- **New model:** `lib/data/models/night_mode_state.dart` — `DayNight` + `NightModeOverride` enums + `NightModeState` (immutable; plain Dart, mirrors `VideoQualityState` style)
- **New provider:** `lib/domain/providers/night_mode_provider.dart` — subscribes to `wsClient.eventStream`, handles `night_mode_state`, exposes `setOverride()`, 90s heartbeat-stale flag
- **New widgets directory:** `lib/presentation/widgets/night_mode/`
  - `mode_badge.dart` — sun/moon badge (drive-screen, display-only)
  - `night_vision_settings_section.dart` — full panel mounted in Settings → "Night Vision"
- **Theme additions:** `AppTheme.primaryNight` (steel-blue) + `AppTheme.darkNight` variant; app.dart watches `nightModeProvider` and swaps theme cyan → steel-blue app-wide when robot is in night mode
- **Wire contract spec:** `.claude/nightvision.md` (committed for robot-side reference)

### Bug fixes also in Build 99:
- **Cold-open auto-connect** — `auth_provider._loadSavedAuth` now mirrors `login()` by calling `connectionProvider.connect()` after silent re-auth (was leaving WS dead on cold open with valid JWT)
- **Multi-robot in-session switch** — `webrtc_provider._handleDeviceSwitch` now triggers `connectionProvider.reconnect()` so the relay rebinds via fresh `session_hello` (was requiring logout+login to switch robots)

### Documentation hygiene:
- Moved `.claude/local_notifications.md` → `archive/local_notifications_SPEC_SHIPPED.md` — feature was already implemented (see `notification_service.dart`); spec lingered uncleaned

## ✨ Session Additions (2026-01-18)

### Flutter Mobile App Setup:
1. **Project initialized** - Flutter app with Riverpod + Freezed
2. **Core networking** - DioClient and WebSocketClient
3. **State management** - Connection, telemetry, control providers
4. **UI screens** - Connect, Home, Drive, Missions, Settings
5. **Theme system** - Dark neon/cyberpunk aesthetic

### Key Dependencies:
- `flutter_riverpod` - State management
- `freezed` + `json_serializable` - Immutable models
- `dio` - HTTP client
- `web_socket_channel` - WebSocket
- `flutter_mjpeg` - Video streaming
- `flutter_joystick` - Drive control
- `go_router` - Navigation

---

*This structure document is the authoritative reference for file locations in the WIM-Z Flutter Mobile App.*