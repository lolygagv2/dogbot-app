# WIM-Z Mobile App

Flutter mobile app for controlling the WIM-Z robotic dog training device.

## Quick Start

```bash
# Install Flutter dependencies
flutter pub get

# Generate Freezed/Riverpod code
dart run build_runner build --delete-conflicting-outputs

# Run on connected device
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # MaterialApp + routing
├── core/                     # Constants, config, networking
├── data/                     # Models, API clients
├── domain/                   # Riverpod providers (state)
└── presentation/             # Screens and widgets
```

## Key Features

- **Connect Screen**: Enter WIM-Z IP address
- **Dashboard**: Live video + status + quick actions
- **Drive Screen**: Joystick control for motors + camera
- **Missions**: Start/stop training sessions
- **Settings**: View robot status, disconnect

## Dependencies

- `flutter_riverpod` - State management
- `freezed` - Immutable data classes
- `dio` - HTTP client
- `web_socket_channel` - WebSocket connection
- `flutter_mjpeg` - Video streaming
- `flutter_joystick` - Touch joystick
- `go_router` - Navigation

## Development

See `CLAUDE_CODE_GUIDE.md` for detailed implementation instructions.

### Generate code after model changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Watch mode:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

## API Reference

The app connects to WIM-Z's FastAPI server. Key endpoints:

| Endpoint | Purpose |
|----------|---------|
| GET /telemetry | Robot status |
| POST /motor/speed | Set motor speeds |
| POST /servo/pan | Set camera pan |
| POST /treat/dispense | Dispense treat |
| POST /led/pattern | Set LED pattern |
| WS /ws | Real-time events |

See `CLAUDE_CODE_GUIDE.md` for full API documentation.

## License

Proprietary - WIM-Z Project
