# WIM-Z Mobile App - Project Directory Structure
*Last Updated: 2026-01-18 - Flutter Mobile App*

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
            websocket_client.dart  WebSocket with auto-reconnect

      📂 data/                     # Data layer
         📂 models/                # Freezed data classes
            telemetry.dart         Robot status model
            mission.dart           Training mission config
         📂 datasources/
            robot_api.dart         REST API client for WIM-Z

      📂 domain/                   # Business logic
         📂 providers/             # Riverpod state management
            connection_provider.dart    Connection state
            telemetry_provider.dart     Robot status updates
            control_provider.dart       Motor, servo, treat, LED, audio

      📂 presentation/             # UI layer
         📂 screens/
            connect/               Initial connection screen
            home/                  Dashboard with video + status
            drive/                 Manual joystick control
            missions/              Training session management
            settings/              Configuration & info
         📂 widgets/
            video/                 MJPEG viewer
            controls/              Joystick, pan/tilt, quick actions
            status/                Battery, connection, detection
            common/                Loading, errors, shared UI
         📂 theme/
            app_theme.dart         Dark theme with neon aesthetics

   📂 test/                        # All test files
      unit/                        Unit tests
      widget/                      Widget tests
      integration/                 Integration tests

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