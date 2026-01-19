# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile app for controlling the WIM-Z robotic dog training device. Connects to WIM-Z's FastAPI server over local network for real-time control, video streaming, and training session management.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Generate Freezed/Riverpod code (run after model changes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation during development
dart run build_runner watch --delete-conflicting-outputs

# Run on connected device
flutter run

# Build release APK
flutter build apk --release

# Build iOS (requires Mac or Codemagic)
flutter build ios --release
```

## Architecture

**Layered, feature-first architecture:**

- `lib/core/` - Shared infrastructure (networking, constants, config)
- `lib/data/` - Models (Freezed classes) and API clients
- `lib/domain/` - Riverpod providers (state management)
- `lib/presentation/` - Screens, widgets, and theme

**Key patterns:**
- Singleton pattern for DioClient and WebSocketClient
- Riverpod StateNotifier for stateful operations
- Freezed for immutable data classes with JSON serialization

## State Management

Uses Riverpod 2.0 with code generation. Key providers:

- `connectionProvider` - Connection state (disconnected/connecting/connected/error)
- `telemetryProvider` - Robot status via polling (2s) + WebSocket events
- `motorControlProvider` / `servoControlProvider` - Control commands at 20Hz
- `treatControlProvider`, `ledControlProvider`, `audioControlProvider` - Quick actions

## Networking

**REST** (Dio): Setup, telemetry queries, LED/audio/servo operations
**WebSocket**: Real-time motor/servo control and event streaming
**MJPEG**: Video stream from `/camera/stream`

WebSocket auto-reconnects with exponential backoff (max 5 attempts, 3s base interval).

## Key Configuration Values

From `lib/core/constants/app_constants.dart`:
- Default port: 8000
- Joystick send rate: 50ms (20Hz)
- Telemetry refresh: 2 seconds
- WebSocket ping: 30 seconds
- Max motor speed: 1.0
- Max pan/tilt: 90°/45°

## Code Generation

After modifying any `@freezed` or `@riverpod` annotated classes, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis via `analysis_options.yaml`.

## WIM-Z API Quick Reference

| Endpoint | Purpose |
|----------|---------|
| GET /telemetry | Robot status |
| GET /health | Connection check |
| POST /motor/speed | `{left: float, right: float}` |
| POST /servo/pan, /servo/tilt | Camera angles |
| POST /treat/dispense | Dispense treat |
| POST /led/pattern | `{pattern: string}` |
| WS /ws | Real-time events and commands |

LED patterns: `breathing`, `rainbow`, `celebration`, `searching`, `alert`, `idle`
Modes: `idle`, `guardian`, `training`, `manual`, `docking`

## Theme

Dark theme only with neon/cyberpunk aesthetic. Primary color is cyan (#00E5FF) matching WIM-Z LED.


# WIM-Z APP - (Watchful Intelligent Mobile Zen) Project - Development Rules

This project is the companion for the WIMZ hardware App that runs on Raspberry Pi 5 and this is making the mobile app to use as the interface

## NEVER DELETE OR MODIFY
- notes.txt (user's personal notes - IGNORE)
- /docs/ folder (reference documentation only)
- Any file with "KEEPME" or "NOTES" in filename

## Project Structure - MUST MAINTAIN
Follow the structure defined in `.claude/WIM-Z_Project_Directory_Structure.md`

**Flutter app structure:**
- `lib/core/` - Networking (DioClient, WebSocketClient), constants, config
- `lib/data/` - Freezed models and API datasources (RobotApi)
- `lib/domain/` - Riverpod providers (state management)
- `lib/presentation/` - Screens, widgets, and theme
- `test/` - ALL test files go here (unit, widget, integration)

## Project Documentation
- .claude/product_roadmap.md - Development timeline and phases
- .claude/development_todos.md - Priority-sorted tasks

## Session Protocol
ALWAYS use /project:session-start when opening
ALWAYS use /project:session-end before closing
NEVER skip these commands

## Test File Rules
- ALL test/debug files go in /tests/ subdirectories
- Name test files: test_<component>_<description>.py
- Before creating ANY new test file, check if similar test exists
- After completing testing phase, ASK before deleting old test files
- NEVER leave test files scattered in main project directories

## Cleanup Protocol
1. Before any cleanup, show me list of files to be removed
2. Wait for explicit approval
3. Move to /tests/archive/ rather than deleting
4. Keep maximum 3 test files per component unless told otherwise

## Development Workflow
1. Plan changes in Plan Mode (Shift+Tab twice)
2. Get approval before file operations
3. Commit incrementally
4. Ask before creating >5 new files

## When Refactoring
- Preserve existing working code structure
- Don't create new test folders outside /tests/
- Clean up as you go, but ASK first