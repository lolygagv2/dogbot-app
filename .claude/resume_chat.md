# WIM-Z Resume Chat Log

## Session: 2026-02-02 — Build 44 Complete
**Goal:** Multiple bug fixes and feature additions
**Status:** ✅ Complete

### Problems Solved This Session:

#### 1. Mission List Sync (Build 41.1)
**Problem:** App had only 5 predefined missions but robot has 21.
**Solution:** Updated `_predefinedMissions` list to match robot's full mission catalog.
**File:** `lib/domain/providers/missions_provider.dart`

#### 2. Scheduler Ghost Entry Fix (Build 41.1)
**Problem:** App showed schedules that failed to create on robot (ghost entries).
**Solution:** Check `success` field in `schedule_created` response; remove optimistic entry if `success: false`.
**File:** `lib/domain/providers/scheduler_provider.dart`

#### 3. BluLight Button (Build 42)
**Problem:** No independent control for blue mood LED.
**Solution:** Added BluLight toggle button to quick actions secondary row; sends `mood_led` relay command.
**Files:** `lib/core/network/websocket_client.dart`, `lib/presentation/widgets/controls/quick_actions.dart`

#### 4. Battery Display Fix (Build 42)
**Problem:** Battery flashing between actual value (96%) and 0% every 5 seconds.
**Solution:** Capture previous battery before event processing; triple fallback chain; only update if level > 0.
**File:** `lib/domain/providers/telemetry_provider.dart`

#### 5. Video Privacy Fix (Build 44) — CRITICAL
**Problem:** Video from previous robot bleeding into new robot session when switching devices.
**Solution:**
- Clear renderer srcObject BEFORE closing connection
- Stop all tracks on stream before clearing
- Longer delay (1s) when switching devices
- Update _lastDeviceId AFTER closing old session

**File:** `lib/domain/providers/webrtc_provider.dart`

### Commits This Session:
```
9b45ac2 fix: Build 41.1 — Mission button race condition, mission list sync, scheduler ghost fix
4202c9a feat: Build 42 — Add BluLight button for blue mood LED control
f7c70a4 fix: Build 42 — Prevent battery display from resetting to 0%
262d4ac chore: Build 44 version bump
76639cb fix: Build 44 — Prevent video bleeding when switching robots (privacy fix)
```

### Key Solutions:
- **WebRTC cleanup sequence:** Clear renderer → Stop tracks → Close peer → Wait 1s → New request
- **Battery preservation:** Never set to 0 unless explicitly sent by robot
- **Scheduler:** Check success field in response, revert optimistic updates on failure

### Next Steps:
1. Test video switching between robots to verify privacy fix
2. Test battery display stability
3. Test BluLight button functionality
4. Fix 30-second video lag (ROBOT-SIDE: `git pull && sudo systemctl restart treatbot` on treatbot2)

### Important Notes:
- Video lag is ROBOT-SIDE issue, not app-side
- Robot code (dogbot repo) is separate from app code (wimzapp repo)
- WebSocket telemetry "unhandled" logs are expected - events handled by other providers

---

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
