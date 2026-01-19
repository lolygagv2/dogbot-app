# WIM-Z Mobile App - Claude Code Implementation Guide

## Project Overview

Build a Flutter mobile app to control the WIM-Z robotic dog training device. The app connects to WIM-Z's FastAPI server for real-time control, video streaming, and training session management.

**Target Timeline:** 14 days (80-hour weeks)
**Platform:** iOS + Android via Flutter + Codemagic
**State Management:** Riverpod 2.0 + Freezed
**Architecture:** Feature-first with clean separation

---

## Phase 1: Local Network MVP (Days 1-5)

Connect directly to WIM-Z on local WiFi. No cloud infrastructure yet.

### Day 1: Project Setup

```bash
# Create Flutter project
flutter create --org com.wimz --project-name wimz_app .

# Add dependencies
flutter pub add flutter_riverpod riverpod_annotation freezed_annotation json_annotation dio web_socket_channel go_router flutter_mjpeg

# Add dev dependencies  
flutter pub add --dev build_runner freezed json_serializable riverpod_generator

# Run code generation
dart run build_runner build --delete-conflicting-outputs
```

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # MaterialApp + GoRouter setup
│
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart   # All REST endpoint paths
│   │   └── app_constants.dart   # Timeouts, defaults
│   ├── config/
│   │   └── environment.dart     # Dev/prod server URLs
│   ├── network/
│   │   ├── dio_client.dart      # HTTP client singleton
│   │   └── websocket_client.dart # WebSocket connection manager
│   └── utils/
│       └── logger.dart          # Debug logging
│
├── data/
│   ├── models/                  # Freezed data classes
│   │   ├── telemetry.dart       # Robot status model
│   │   ├── detection.dart       # Dog detection data
│   │   ├── mission.dart         # Training mission config
│   │   └── command.dart         # Control commands
│   ├── datasources/
│   │   ├── robot_api.dart       # REST API calls
│   │   └── robot_websocket.dart # WebSocket event handling
│   └── repositories/
│       └── robot_repository.dart # Combines API + WS
│
├── domain/
│   └── providers/               # Riverpod providers
│       ├── connection_provider.dart    # Connection state
│       ├── telemetry_provider.dart     # Live robot status
│       ├── video_provider.dart         # MJPEG stream
│       ├── control_provider.dart       # Motor/servo commands
│       └── mission_provider.dart       # Training sessions
│
└── presentation/
    ├── screens/
    │   ├── home/
    │   │   └── home_screen.dart        # Main dashboard
    │   ├── drive/
    │   │   └── drive_screen.dart       # Manual control
    │   ├── missions/
    │   │   ├── missions_screen.dart    # Mission list
    │   │   └── mission_detail_screen.dart
    │   ├── settings/
    │   │   └── settings_screen.dart    # Server config
    │   └── connect/
    │       └── connect_screen.dart     # Initial connection
    │
    ├── widgets/
    │   ├── video/
    │   │   └── mjpeg_viewer.dart       # Video stream widget
    │   ├── controls/
    │   │   ├── joystick.dart           # Drive joystick
    │   │   ├── pan_tilt_control.dart   # Camera gimbal
    │   │   └── quick_actions.dart      # Treat, LED, audio buttons
    │   ├── status/
    │   │   ├── battery_indicator.dart
    │   │   ├── connection_badge.dart
    │   │   └── detection_overlay.dart  # AI detection boxes
    │   └── common/
    │       └── loading_overlay.dart
    │
    └── theme/
        └── app_theme.dart              # Colors, typography
```

---

## WIM-Z API Reference

The WIM-Z runs a FastAPI server. Here are the key endpoints to implement:

### Connection & Status

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/telemetry` | Full system status (battery, temp, mode, detection) |
| GET | `/health` | Simple alive check |
| WS | `/ws` | Real-time events (detection, status changes) |

### Motor Control

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/motor/speed` | Set motor speeds `{left: float, right: float}` |
| POST | `/motor/stop` | Stop all motors |
| POST | `/motor/emergency` | Emergency stop |

### Camera & Servos

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/camera/stream` | MJPEG video stream |
| GET | `/camera/snapshot` | Single JPEG frame |
| POST | `/servo/pan` | Set pan angle `{angle: float}` |
| POST | `/servo/tilt` | Set tilt angle `{angle: float}` |
| POST | `/servo/center` | Center camera |

### Treat Dispenser

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/treat/dispense` | Dispense one treat |
| POST | `/treat/carousel/rotate` | Rotate carousel |

### LED Control

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/led/pattern` | Set pattern `{pattern: string}` |
| POST | `/led/color` | Set color `{r: int, g: int, b: int}` |
| POST | `/led/off` | Turn off LEDs |

Available patterns: `breathing`, `rainbow`, `celebration`, `searching`, `alert`, `idle`

### Audio

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/audio/play` | Play sound `{file: string}` |
| POST | `/audio/stop` | Stop playback |
| POST | `/audio/volume` | Set volume `{level: int}` (0-100) |
| GET | `/audio/files` | List available audio files |

### Mode Control

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/mode/get` | Current mode |
| POST | `/mode/set` | Set mode `{mode: string}` |

Available modes: `idle`, `guardian`, `training`, `manual`, `docking`

### Missions (Training Sessions)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/missions` | List all missions |
| GET | `/missions/{id}` | Get mission details |
| POST | `/missions/{id}/start` | Start a mission |
| POST | `/missions/{id}/stop` | Stop running mission |
| GET | `/missions/active` | Get currently running mission |

---

## WebSocket Events

Connect to `ws://{host}:8000/ws` for real-time updates.

### Incoming Events (Robot → App)

```json
// Dog detection
{"event": "detection", "data": {"detected": true, "behavior": "sitting", "confidence": 0.92, "bbox": [x, y, w, h]}}

// Status change
{"event": "status", "data": {"battery": 78, "mode": "training", "temp": 42}}

// Treat dispensed
{"event": "treat", "data": {"remaining": 12, "timestamp": "..."}}

// Mission progress
{"event": "mission", "data": {"id": "sit_training", "progress": 0.6, "rewards_given": 3}}

// Error
{"event": "error", "data": {"code": "LOW_BATTERY", "message": "Battery below 20%"}}
```

### Outgoing Commands (App → Robot)

```json
// Motor command (send frequently for smooth control)
{"command": "motor", "left": 0.5, "right": 0.5}

// Servo command
{"command": "servo", "pan": 15.0, "tilt": -10.0}

// Quick actions
{"command": "treat"}
{"command": "led", "pattern": "celebration"}
{"command": "audio", "file": "good_dog.mp3"}
```

---

## Implementation Priority

### Must Have (Days 1-5)
1. **Connect screen** - Enter IP address, test connection, save to preferences
2. **Dashboard** - Video stream + battery + mode + last detection
3. **Drive screen** - Joystick for motors + pan/tilt for camera
4. **Treat button** - One-tap treat dispensing
5. **WebSocket connection** - Real-time status updates

### Should Have (Days 6-10)
6. **Mission list** - View available training sessions
7. **Mission control** - Start/stop missions, see progress
8. **LED patterns** - Quick pattern buttons
9. **Audio playback** - Play training sounds
10. **Detection overlay** - Show AI bounding boxes on video

### Nice to Have (Days 11-14)
11. **Settings screen** - Server config, preferences
12. **Statistics** - Training history, success rates
13. **Dark mode** - Theme toggle
14. **Haptic feedback** - Vibration on treat dispense

---

## Key Implementation Details

### MJPEG Video Stream

Use `flutter_mjpeg` package for the video stream:

```dart
MjpegViewer(
  stream: 'http://${serverIp}:8000/camera/stream',
  isLive: true,
  fit: BoxFit.contain,
  error: (context, error, stack) => Icon(Icons.error),
)
```

### Joystick Control

For driving, send motor commands at ~20Hz while joystick is active:

```dart
// Convert joystick x,y to differential drive
final left = (y + x).clamp(-1.0, 1.0);
final right = (y - x).clamp(-1.0, 1.0);

// Send via WebSocket for lowest latency
websocket.send(jsonEncode({
  'command': 'motor',
  'left': left,
  'right': right,
}));
```

### Connection State Management

```dart
@riverpod
class ConnectionNotifier extends _$ConnectionNotifier {
  @override
  ConnectionState build() => ConnectionState.disconnected;
  
  Future<void> connect(String host) async {
    state = ConnectionState.connecting;
    try {
      // Test REST endpoint
      await ref.read(dioClientProvider).get('http://$host:8000/health');
      // Connect WebSocket
      await ref.read(websocketClientProvider).connect('ws://$host:8000/ws');
      state = ConnectionState.connected;
    } catch (e) {
      state = ConnectionState.error;
    }
  }
}
```

### Freezed Models Example

```dart
// lib/data/models/telemetry.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry.freezed.dart';
part 'telemetry.g.dart';

@freezed
class Telemetry with _$Telemetry {
  const factory Telemetry({
    required double battery,
    required double temperature,
    required String mode,
    required bool dogDetected,
    String? currentBehavior,
    double? confidence,
  }) = _Telemetry;

  factory Telemetry.fromJson(Map<String, dynamic> json) => _$TelemetryFromJson(json);
}
```

---

## Testing Checklist

### Local Network Tests

- [ ] App discovers WIM-Z on local network (manual IP entry for now)
- [ ] Video stream displays with <500ms latency
- [ ] Joystick controls motors smoothly (no jitter)
- [ ] Pan/tilt moves camera in real-time
- [ ] Treat dispenses on button press
- [ ] Battery level updates automatically
- [ ] Mode changes reflect in UI
- [ ] Detection events show in UI
- [ ] App reconnects after WiFi interruption

### Device Tests

- [ ] Works on Android emulator
- [ ] Works on physical Android device
- [ ] Works on iOS simulator
- [ ] Works on physical iPhone (requires Codemagic or Mac)

---

## Environment Configuration

Create `lib/core/config/environment.dart`:

```dart
enum Environment { dev, prod }

class AppConfig {
  static Environment env = Environment.dev;
  
  static String get defaultHost {
    switch (env) {
      case Environment.dev:
        return '192.168.1.50'; // Your WIM-Z's IP
      case Environment.prod:
        return 'api.wimz.io'; // Future cloud endpoint
    }
  }
  
  static int get defaultPort => 8000;
  
  static String get wsScheme => env == Environment.prod ? 'wss' : 'ws';
  static String get httpScheme => env == Environment.prod ? 'https' : 'http';
}
```

---

## Common Issues & Solutions

### Video stream not loading
- Check CORS settings on WIM-Z FastAPI server
- Verify `/camera/stream` endpoint is running
- Try `/camera/snapshot` first to verify camera works

### WebSocket disconnects frequently
- Implement heartbeat ping every 30 seconds
- Add exponential backoff reconnection
- Check WiFi signal strength

### Joystick feels laggy
- Use WebSocket, not REST for motor commands
- Send commands at fixed rate (20Hz), not on every frame
- Debounce joystick input slightly

### App crashes on background
- Disconnect WebSocket when app goes to background
- Reconnect when app returns to foreground
- Use `WidgetsBindingObserver` to detect lifecycle changes

---

## Phase 2 Preview: WebRTC (Days 6-10)

After local network works, add WebRTC for better video:

1. Add `flutter_webrtc` package
2. Implement WebRTC signaling via REST/WebSocket
3. Create `WebRTCViewer` widget as alternative to MJPEG
4. Add toggle in settings: MJPEG vs WebRTC

---

## Phase 3 Preview: Cloud Relay (Days 11-14)

Enable internet access:

1. WIM-Z connects outbound to relay server
2. App connects to same relay server
3. Relay brokers WebRTC signaling
4. Commands proxied through relay

Architecture:
```
Phone App ←→ Cloud Relay (Fly.io) ←→ WIM-Z Robot
```

---

## Commands Quick Reference

```bash
# Generate Freezed/Riverpod code after model changes
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs

# Run on connected device
flutter run

# Build release APK
flutter build apk --release

# Build iOS (requires Mac or Codemagic)
flutter build ios --release
```

---

## Success Criteria

**Phase 1 Complete When:**
- [ ] Can connect to WIM-Z by entering IP address
- [ ] Live video stream displays on dashboard
- [ ] Can drive robot with on-screen joystick
- [ ] Can pan/tilt camera with on-screen control
- [ ] Can dispense treats with one tap
- [ ] Battery and mode display correctly
- [ ] Dog detection events appear in UI

**Ready for Beta When:**
- [ ] All Phase 1 + Phase 2 + Phase 3 complete
- [ ] Works from outside home network
- [ ] Can start/stop training missions
- [ ] Handles disconnections gracefully
- [ ] Tested on 3+ physical devices
