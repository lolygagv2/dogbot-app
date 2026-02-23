# WIM-Z Resume Chat Log

## Session: 2026-02-22 — Build 48/49 (Bug Fixes + Mode Sync)
**Goal:** Fix 6 UI/UX bugs (Build 48) + mode timeout trust fix (Build 49)
**Status:** ✅ Complete — awaiting user test of Build 49

### Problems Solved This Session:

#### Build 48 — 6 Bug Fixes + 3 Mode Sync Holes + Bark Events

| # | Bug | Fix | File |
|---|-----|-----|------|
| 1 | "DEMO" label persists after logout/login | Added `isDemoMode: false` to disconnect() copyWith | `connection_provider.dart` |
| 2 | D-pad touch areas too small on drive screen | Enlarged to 56x56 hit area, 44x44 visual, Clip.none + HitTestBehavior.opaque | `drive_screen.dart` |
| 3 | Mode dropdown stuck after switching to SG/Coach | Ignore stale non-matching modes during pending state | `mode_provider.dart` |
| 4 | Sound icon overlaps photo icon on video | Moved camera button from bottom-right to bottom-left | `webrtc_video_view.dart` |
| 5 | Mode selector taking up video space | Removed overlay, created _ModeAndDriveRow with segmented buttons below video | `home_screen.dart` |
| 6 | Hardcoded test@wimz.com login | SharedPreferences to save/load last email, host, port | `login_screen.dart` |

**Additional Build 48 fixes:**
- **Bark timestamps:** Fixed spread order in websocket_client.dart so local timestamp wins over relay server time; added `.toLocal()` in guardian_event.dart
- **Bark activity:** Added 'event' type handler in notifications_provider.dart so barks appear in Activity tab
- **3 mode sync holes closed:**
  1. `_handleModeChangedEvent` — added pending-state protection
  2. `_syncFromTelemetry` — now checks `_lastModeChangeTime` with 8s post-change cooldown
  3. Extended user cooldown from 2s to 5s

#### Build 49 — Mode Timeout Trust Fix
**Problem:** After Build 48 mode sync fixes, mode changes worked but showed "mode change timed out" error. Robot-side bugs (relay_client.py uses state.set_mode() instead of mode_fsm.set_mode_override(), battery events send stale mode) mean confirmation never arrives.
**Solution:** Changed `_onTimeout()` to trust the command instead of reverting — if no error/rejection came back, accept the pending mode. Telemetry sync will correct if robot disagrees after cooldown.
**File:** `lib/domain/providers/mode_provider.dart`

### Files Changed:
- `lib/domain/providers/connection_provider.dart` — isDemoMode clear on disconnect
- `lib/domain/providers/mode_provider.dart` — 4 iterations of mode sync fixes + timeout trust
- `lib/presentation/screens/auth/login_screen.dart` — Persist login credentials
- `lib/presentation/screens/drive/drive_screen.dart` — Enlarged D-pad touch targets
- `lib/presentation/screens/home/home_screen.dart` — Mode row below video, EXIT button
- `lib/presentation/widgets/video/webrtc_video_view.dart` — Camera button repositioned
- `lib/core/network/websocket_client.dart` — Bark event spread order fix
- `lib/data/models/guardian_event.dart` — .toLocal() for UTC timestamps
- `lib/domain/providers/notifications_provider.dart` — Bark events in Activity tab
- `pubspec.yaml` — Version 1.0.0+49

### Commits This Session:
```
e0207b4 fix: Build 49 — Trust mode command on timeout instead of reverting
20891bb chore: Build 49 version bump
38ac08e fix: Build 48 — Close 3 mode sync holes causing revert to Idle
f99fc4f fix: Build 48 — Bark event timestamp uses local time, barks show in Activity tab
8624be1 fix: Build 48 — 6 bug fixes (DEMO label, D-pad touch, mode sync, icon overlap, mode exit UX, login persist)
```

### Robot-Side Bugs Identified (not yet fixed):
- `relay_client.py:537` — uses `state.set_mode()` instead of `mode_fsm.set_mode_override()`
- `main_treatbot.py:766` — battery events sent every 30s with stale mode
- Fix: use `mode_fsm.set_mode_override()` in relay handler

### Next Steps:
1. User to test Build 49 mode switching (trust-on-timeout fix)
2. Deploy robot-side fix (mode_fsm.set_mode_override in relay_client.py)
3. Once robot fix deployed, app should receive proper mode confirmations

---

## Session: 2026-02-22 — Build 47 (v1.3 API Contract)
**Goal:** Implement v1.3 API contract — audio streaming, mode restructure, UI overhaul, diagnostic audit
**Status:** ✅ Complete

### Problems Solved This Session:

#### 1. Always-On Audio Streaming (Task 1)
**Problem:** Robot now sends audio track via WebRTC alongside video. App had no audio handling.
**Solution:**
- `webrtc_provider.dart` — Accept audio track in `onTrack` callback, store `_audioStream`, control via `track.enabled`
- `audio_mute_toggle.dart` (NEW) — Small speaker icon on video feed, tap to toggle
- Mute state persists via SharedPreferences (key: `webrtc_audio_muted`), default MUTED
- Removed "Tap to Listen" button entirely (replaced by streaming)
- Added `PushToTalkMicOnly` widget (mic-only, no listen button) for drive screen

#### 2. Mode/UX Restructure (Task 2)
**Problem:** Mode dropdown showed all 5 modes everywhere. No restore-previous-mode logic.
**Solution:**
- Portrait dropdown: idle/guardian/coach only (3 options)
- Landscape selector: manual/coach/mission (popup on drive screen)
- `set_mode` command now includes `source` and `timestamp` per v1.3 contract
- Added `previousPortraitMode` to ModeState — stored on Drive enter, restored on exit
- Mission end restores previous portrait mode instead of defaulting to idle
- "Switching to Manual" overlay changed from blocking to brief toast

#### 3. UI Layout Fixes (Task 3)
**Problem:** Cluttered portrait layout, duplicate nav entries, old audio buttons.
**Solution:**
- Removed Drive/Missions/Settings card row from portrait
- Added prominent Drive button (full-width ElevatedButton)
- PTT mic added to quick actions row (6 items: PTT/Good/Call/Treat/Want/No)
- Consolidated lighting+blue buttons left, music player right in single row
- Bottom nav now 6 items: Home/Dogs/Missions/Photos/Activity/Settings
- Settings moved from standalone route into ShellRoute
- Video area gets more flex space (5:3 ratio)

#### 4. Mode Switching Diagnostic Audit (Task 4)
**Problem:** Intermittent mode revert bugs reported but not currently manifesting.
**Root cause:** Pre-Build-36 race condition — status_update with `mode:idle` would overwrite user's pending mode change. Build 36 added 2-second cooldown that blocks this.
**Delivered:** `MODE_AUDIT_FINDINGS.md` with full code trace of all mode switching paths.

### Files Changed:
- `lib/domain/providers/webrtc_provider.dart` — Audio track handling, mute toggle, SharedPreferences
- `lib/core/network/websocket_client.dart` — sendModeCommand with source+timestamp
- `lib/domain/providers/mode_provider.dart` — previousPortraitMode, source param, mission end restore
- `lib/presentation/screens/home/home_screen.dart` — Portrait dropdown (3 modes), removed nav cards, Drive button
- `lib/presentation/screens/drive/drive_screen.dart` — Store/restore portrait mode, landscape mode selector, toast overlay
- `lib/presentation/widgets/controls/quick_actions.dart` — PTT in action row, consolidated secondary row
- `lib/presentation/widgets/controls/push_to_talk.dart` — Added PushToTalkMicOnly
- `lib/presentation/widgets/video/audio_mute_toggle.dart` (NEW) — Mute toggle widget
- `lib/app.dart` — 6-item bottom nav, Settings in ShellRoute
- `MODE_AUDIT_FINDINGS.md` (NEW) — Diagnostic audit document

### Commits This Session:
```
6f851b9 feat: Build 47 — v1.3 API contract (audio streaming, mode restructure, UI overhaul)
```

### Good Button Audio Fix Note:
- App code is correct: `sendPlayVoice('good', dogId: selectedDog.id)` sends `play_voice` command
- Robot resolves file path server-side — issue is likely robot-side, not app-side

### Next Steps:
1. Test audio streaming with real robot (verify audio track received)
2. Test mode restore flow: portrait → drive → back → verify mode restored
3. Test mission entry/exit with portrait mode restore
4. Verify landscape mode selector (manual/coach/mission switching)
5. Robot-side: verify `set_mode` handles new `source` and `timestamp` fields
6. Robot-side: investigate Good button audio file path

---

## Session: 2026-02-21 — Build 46 (Rate Limit Handling)
**Goal:** Handle new RATE_LIMITED error code from relay
**Status:** ✅ Complete

### Problems Solved This Session:

#### 1. Rate Limit Error Handling (Build 46)
**Problem:** Relay now rate-limits app-to-robot commands (30 per 60s). Returns `{"type": "error", "code": "RATE_LIMITED", ...}` — app had no handling for this.
**Solution:**
- Added `rateLimitStream` to `WebSocketClient` — emits when RATE_LIMITED error received
- Added `rateLimitProvider` (StreamProvider) in `connection_provider.dart`
- `MainShell` listens via `ref.listen` and shows floating orange snackbar: "Too many commands, slow down" (3s duration)
- No command retry on rate limit

**Files Changed:**
- `lib/core/network/websocket_client.dart` — rateLimitStream + emit in error handler
- `lib/domain/providers/connection_provider.dart` — rateLimitProvider
- `lib/app.dart` — snackbar listener in MainShell

### Commits This Session:
```
e57a521 feat: Handle RATE_LIMITED error from relay with snackbar
62889ba chore: Build 46 version bump
```

### Investigation Notes:
- Login screen pre-fills `test@wimz.com` / `test1234` — hardcoded in `login_screen.dart:35-36`
- Default robot ID `wimz_robot_01` hardcoded in `app_constants.dart:38` as fallback
- Device ID persists via SharedPreferences (`paired_device_id` key) after pairing

### Next Steps:
1. Consider removing hardcoded test credentials before production
2. Test rate limit snackbar with real relay

---

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
