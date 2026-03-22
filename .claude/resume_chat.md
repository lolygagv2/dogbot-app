# WIM-Z Resume Chat Log

## Session: 2026-03-22 — Build 59 (Treat Counter, Video Capture, Activity Dashboard)
**Goal:** Implement Items 13, 15, 16 — video capture button, treat counter UI, dog metrics dashboard
**Status:** Completed — pushed to main

### Problems Solved This Session:

#### Build 59 — Three Expo Features

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 15 | Treat Counter UI | P1 | AppBar indicator + bottom sheet for expo reset |
| 13 | Video Capture Button | P2 | Record button next to camera, gallery save |
| 16 | Dog Metrics Dashboard | P2 | "Money slide" — chart + event log for investors |

#### Treat Counter Fix (post-build hotfix)
**Problem:** Telemetry provider was reading `treats_today` instead of `treats_remaining` in 3 places. Default of `0` couldn't distinguish "missing field" from "actually zero".
**Solution:**
- Changed all `treats_today` → `treats_remaining` in battery event + _extractBatteryFromAnyEvent
- Default changed to `-1` sentinel (Freezed model), provider returns `null` for "no data"
- UI shows "—" when no data, "0 (refill)" for zero/negative, color tiers for > 0
- No optimistic UI update — waits for telemetry confirmation after set/reset

### Files Created:
- `lib/data/services/video_service.dart` — Base64 video → temp file → Gal.putVideo()
- `lib/domain/providers/video_provider.dart` — VideoState, 60s max recording, auto-stop
- `lib/presentation/screens/notifications/activity_dashboard.dart` — fl_chart line chart, stats, event log
- `lib/presentation/widgets/status/treat_counter_indicator.dart` — Cookie icon + count + management sheet

### Files Modified:
- `lib/core/network/websocket_client.dart` — Video stream, recording commands, treat counter commands
- `lib/data/models/telemetry.dart` — treatsRemaining default -1 sentinel
- `lib/domain/providers/telemetry_provider.dart` — treats_remaining field, nullable provider
- `lib/domain/providers/control_provider.dart` — TreatControl.setCount/resetCount
- `lib/domain/providers/analytics_provider.dart` — dogWeeklyStatsProvider, activityTabIndexProvider
- `lib/presentation/screens/home/home_screen.dart` — TreatCounterIndicator in AppBar
- `lib/presentation/screens/notifications/notifications_screen.dart` — Tabbed (Dashboard|Events)
- `lib/presentation/screens/dog_profile/dog_profile_screen.dart` — "View Dashboard" button
- `lib/presentation/widgets/video/webrtc_video_view.dart` — _VideoRecordButton with pulse animation
- `pubspec.yaml` — Version 1.0.0+59

### Commits This Session:
```
8abee32 feat: Build 59 — Treat counter, video capture, activity dashboard
0de3055 fix: Treat counter reads treats_remaining, handles missing/negative
```

### Key Implementation Details:
- **Treat counter 2-tap expo flow:** Tap cookie icon → "Reset to Full" → sends WS command → done
- **Video record button:** Pulsing red animation (AnimationController), auto-stop at 60s
- **Activity dashboard:** fl_chart 0.66 LineChart with 7-day activity score, demo data trending upward
- **Notifications screen:** Refactored to TabBar with Dashboard + Events tabs
- **Telemetry sentinel pattern:** `-1` default = "never received", `null` in provider = show "—"

### Next Steps:
1. Test treat counter with live robot (verify treats_remaining field arrives)
2. Test video recording flow end-to-end (robot must support start_recording/stop_recording)
3. Verify fl_chart renders correctly on iOS/Android
4. Dashboard data is demo/mock — wire to real analytics when API ready

---

## Session: 2026-02-25 — Build 56/57 (Mission UX Fixes)
**Goal:** Fix 3 mission UX issues: Play→Drive nav, compact banner, restart glitch + hotfix mode race
**Status:** Completed — pushed, needs Codemagic trigger (manual)

### Problems Solved This Session:

#### Build 56 — Mission UX Fixes (3 issues)

| # | Bug | Fix | File |
|---|-----|-----|------|
| 1 | No auto-navigate to drive after starting mission | Replace snackbar with `context.go('/home') + context.push('/drive')` | `mission_detail_screen.dart` |
| 2 | Active mission banner spans full width on drive | Removed `right: 16` from Positioned — now compact left-pinned chip | `drive_screen.dart` |
| 3 | Can't restart mission after completion (state stuck) | Added `_completedMissionId` guard to reject stale progress events | `missions_provider.dart` |

**Also added:** DRIVE button on `_ActiveMissionCard` in `missions_screen.dart` for users who go back to missions list

#### Build 57 — Hotfix: Mission Mode Race Condition
**Problem:** Build 56's auto-navigate to drive introduced a race condition. Drive screen `initState` checked `modeStateProvider.isMissionActive` which only updates after robot confirms mission — not yet set during navigation. Fell through to `_ensureManualMode()` → robot abandoned mission mode.
**Solution:** Added `missionsProvider.hasActiveMission` check (optimistically set on `startMission()`) to both `initState` and `build()` method in drive_screen.dart.
**File:** `lib/presentation/screens/drive/drive_screen.dart`

### Commits This Session:
```
a01fbbc feat: Build 56 — Mission UX fixes (Play→Drive, compact banner, restart glitch)
fbe4235 fix: Prevent drive screen from overriding mission mode on entry
c83d7da chore: Build 57 version bump
```

### Known Issue (user-reported, NOT caused by our changes):
- Motor controls not working — git diff confirmed no motor/joystick code was touched
- Needs investigation next session (could be robot-side or WebSocket issue)

---

## Session: 2026-02-22 — Build 48/49 (Bug Fixes + Mode Sync)
**Goal:** Fix 6 UI/UX bugs (Build 48) + mode timeout trust fix (Build 49)
**Status:** Completed — awaiting user test of Build 49

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

#### Build 49 — Mode Timeout Trust Fix
**Problem:** After Build 48 mode sync fixes, mode changes worked but showed "mode change timed out" error.
**Solution:** Changed `_onTimeout()` to trust the command instead of reverting.
**File:** `lib/domain/providers/mode_provider.dart`

### Commits This Session:
```
e0207b4 fix: Build 49 — Trust mode command on timeout instead of reverting
20891bb chore: Build 49 version bump
38ac08e fix: Build 48 — Close 3 mode sync holes causing revert to Idle
f99fc4f fix: Build 48 — Bark event timestamp uses local time, barks show in Activity tab
8624be1 fix: Build 48 — 6 bug fixes (DEMO label, D-pad touch, mode sync, icon overlap, mode exit UX, login persist)
```

---

## Session: 2026-02-22 — Build 47 (v1.3 API Contract)
**Goal:** Implement v1.3 API contract — audio streaming, mode restructure, UI overhaul
**Status:** Completed

### Commits:
```
6f851b9 feat: Build 47 — v1.3 API contract (audio streaming, mode restructure, UI overhaul)
```

---

## Previous Sessions

### Build 46 — 2026-02-21 — Rate Limit Handling
### Build 44 — 2026-02-02 — Bug Fixes (battery display, video privacy, BluLight)
### Build 38 — 2026-02-01 — Ghost Commands, MP3 Upload, Scheduler WebSocket
### Build 37 — 2026-01-31 — Mode cycling fix, upload timeout
### Build 36 — 2026-01-30 — Schedule API format updates
### Build 35 — 2026-01-29 — Schedule, coach mode, mission fixes
