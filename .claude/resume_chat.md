# WIM-Z Resume Chat Log

## Session: 2026-02-01 — Build 38 Complete
**Goal:** Implement Build 38 fixes from BUILD38_APP_CLAUDE.md
**Status:** ✅ Complete

### Problems Solved This Session:

#### P0-A1: Ghost Commands (CRITICAL)
**Problem:** App was sending `stop_mission`, `stop_coach`, and `set_mode` commands during screen navigation, killing missions behind the user's back.

**Solution:**
- Removed `PopScope` wrapper from `coach_screen.dart` that sent `stop_coach` on back navigation
- Removed auto `set_mode(idle)` from `stopCoaching()` in `coach_provider.dart`
- Removed `sendManualControlActive/Inactive` from `drive_screen.dart` initState/dispose
- Cleaned up unused imports and fields

**Files Changed:**
- `lib/presentation/screens/coach/coach_screen.dart`
- `lib/domain/providers/coach_provider.dart`
- `lib/presentation/screens/drive/drive_screen.dart`

#### P1-A4: MP3 Upload Crash
**Problem:** 5MB base64 over WebSocket crashed the robot's connection.

**Solution:**
- Switched to HTTP multipart POST to `/api/music/upload`
- No more base64 encoding (raw file via multipart form)
- Added `dog_id` field for associating upload with dog profile
- Added progress tracking and specific error messages

**Files Changed:**
- `lib/core/constants/api_endpoints.dart` — Added `musicUpload` endpoint
- `lib/data/datasources/robot_api.dart` — Added `uploadMusic()` method
- `lib/presentation/widgets/controls/quick_actions.dart` — Replaced WebSocket upload

#### P2-A7: Scheduler to WebSocket
**Problem:** Schedule CRUD went to relay REST API, but robot needs local storage for offline execution.

**Solution:**
- All schedule operations now via WebSocket to robot
- Robot stores schedules locally
- App listens for schedule events (schedules_list, schedule_created, etc.)
- Optimistic updates with timeout-based rollback

**Files Changed:**
- `lib/core/network/websocket_client.dart` — Added schedule commands
- `lib/domain/providers/scheduler_provider.dart` — Replaced REST with WebSocket

### Commits This Session:
```
62f2507 chore: Update to Build 38
513beb5 fix: Build 38 — Switch scheduler to WebSocket commands (P2-A7)
e66db1f fix: Build 38 — Switch MP3 upload to HTTP multipart (P1-A4)
c2fde4c fix: Build 38 — Remove ghost commands from lifecycle handlers (P0-A1)
```

### Analysis Results:
- `flutter analyze lib/` — No errors (337 info-level suggestions, mostly `withOpacity` deprecation)
- Build requires Android SDK (not available in WSL environment)

### Unresolved Issues/Warnings:
- `withOpacity` deprecation warnings throughout codebase (non-blocking, cosmetic)
- `wimz-app-theme/` directory has errors but is separate from main app

### Next Steps:
1. Build APK on machine with Android SDK: `flutter build apk --release`
2. Test ghost command fixes: Start mission → navigate away → verify mission still running
3. Test MP3 upload: Upload file → verify no robot disconnect
4. Test scheduler: Create schedule → verify it persists on robot

### Architecture Rules Enforced (from BUILD38_APP_CLAUDE.md):
1. Robot state is authoritative — App displays what robot says
2. App is thin display/command layer — No caching state, no autonomous commands
3. Commands fire ONLY on explicit user tap — No lifecycle/navigation commands
4. File transfers use HTTP, not WebSocket
5. Schedules live on robot via WebSocket

---

## Session: 2026-02-01 (Earlier) — Build 37.1
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

### Key Files Modified:

| File | Changes |
|------|---------|
| `lib/domain/providers/mode_provider.dart` | Added `_userInitiatedChangeTime` + 2s cooldown; fixed mode locking to require explicit 'started' action |
| `lib/presentation/widgets/controls/quick_actions.dart` | Added `_uploadTimeoutTimer` (10s) with warning message |
| `lib/data/datasources/robot_api.dart` | Added specific error messages for schedule creation (404, 501, 503, 401) |
| `.claude/WHY37BUILD_SUCKS.md` | Comprehensive analysis of all Build 37 issues |

---

## Previous Sessions

### Build 37 — 2026-01-31
- Mode cycling fix
- Upload timeout warning
- Scheduler error messages

### Build 36 — 2026-01-30
- Updated build number
- Schedule API format updates

### Build 35 — 2026-01-29
- APP fixes for schedule, coach mode, mission errors
- Updated schedule API to match Robot format
