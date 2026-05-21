# WIM-Z Resume Chat Log

## Session: 2026-05-21 — Reconnect-Storm Fix + Video-Quality Control + System Volume (Builds 96–98)
**Goal:** Diagnose the ~60s video delay & fix it; then two coordinated robot-side features (adaptive-bitrate video quality, system volume).
**Status:** Completed — all shipped. 11 commits pushed to main. Ends on Build 1.0.0+98.

### Part C — Video quality (adaptive bitrate) — commit a5c0959
Robot ships adaptive bitrate (480p/540p/720p) and publishes `video_quality_state` on the WebRTC data channel; app adds reception + user override.
- **Task 1:** `webrtc_provider`'s data-channel handler was a bare `print()` — replaced with a discriminated-union dispatch (`_handleDataChannelMessage`, switch on `type`). New `video_quality_provider.dart`: `VideoTier`/`VideoQualityMode` enums, immutable `VideoQualityState`, `videoQualityStateProvider` (null = none yet; cleared on WebRTC teardown).
- **Task 2:** `AppSettings.videoQualityMode` (auto/low/medium/high) persisted via SharedPreferences; `setVideoQualityMode()` also sends the `set_video_quality` command (`websocket_client.sendVideoQualityMode` → bare `{type,mode}` frame). New "Video" section in settings_screen with a 4-way SegmentedButton + live "Currently streaming: <tier>" line.
- **Task 3:** No drive-mode connection warning exists in `lib/` — nothing to remove (`_IcePathBadge` is an informational LAN/WAN badge, not a warning).
- Interpretation calls: "per-user" persistence → app-wide SharedPreferences key (single-user/-device app; key not robot-scoped, honoring "not per-robot"). No auto-re-send of the persisted mode on reconnect (not in spec).

### Part D — System volume (robot VolumeManager contract) — commit abd60a9
Robot's `VolumeManager` is the single source of truth (persists across reboots, default 60%, can change via Xbox Share button). App reconciles, never caches.
- `telemetry.dart`: new `volume` field (`int?` 0-100, null=unavailable), parsed from `data.volume` in status telemetry. **Freezed regenerated.**
- `telemetry_provider`: carries `volume` through status updates, preserving last value when omitted.
- New `volume_provider.dart` — `VolumeNotifier` reconciles the slider to telemetry `volume` every ~5s (contract's preferred read); on user change sends the command, marks `syncing`, clears it on telemetry confirm (8s timeout fallback).
- `websocket_client.sendAudioVolume` now sends both `volume` (canonical) + `level` (alias) — valid on every documented write path.
- `quick_actions.dart`: removed the hard-coded `_volumeProvider` (default 70) + its debounce; new `_VolumeSlider` ConsumerWidget (drag=preview, release=commit, sync spinner).
- **Superseded decision:** the earlier "REST POST for set" choice is dropped — the contract states cloud mode has no direct HTTP path to the robot, so the relay `audio_volume` command is the set path (works for both cloud and LAN).
- This closes the volume task that was left UNFINISHED earlier in the session (it was blocked on the robot contract).

### Builds
- Build 96 (`e07bdb5`): trace logging. Build 97 (`95f2165`): ITMS-90683 fix. Build 98 (`4103c49`): version bump carrying Parts C + D.

### Verification
- `flutter analyze` clean on every touched file across Parts C & D (pre-existing infos/2 warnings only).
- `dart run build_runner build` succeeded — only `telemetry.freezed/g.dart` changed.

### New files this session (4)
- `lib/core/utils/conn_trace.dart`, `lib/presentation/screens/settings/connection_diagnostics_screen.dart` (Part A/B)
- `lib/domain/providers/video_quality_provider.dart` (Part C)
- `lib/domain/providers/volume_provider.dart` (Part D)

### Open items / next steps
- Trigger Codemagic for **Build 98** (manual).
- `.claude/local_notifications.md` — untracked `flutter_local_notifications` spec; not implemented.
- Carried from Build 94/95: run `scripts/generate_aruco_markers.py` + uncomment the assets line; file relay ticket for blind `(user_id, device_id)` unpair.
- `connTrace` + Connection Diagnostics screen intentionally retained — the only Mac-free way to diagnose connection regressions.

---

## Session: 2026-05-21 (Part A/B) — WebRTC 60s-Delay Diagnosis + Reconnect-Storm Fix (Builds 96/97)
**Goal:** Diagnose why video feed took ~60s to appear after login; build on-device diagnostics; fix root cause.
**Status:** Completed — root cause fixed, video feed confirmed back to a few seconds. 7 commits pushed to main.

### Root cause (3-codebase coordinated diagnosis: app + relay + robot)
The 60s delay was **not** WebRTC. The app was in a relay reconnect storm and WebRTC never got to start:
- App sent `debug_log` as the **first WS frame** instead of `session_hello` → relay 4000-closes (malformed handshake).
- `RemoteLogger.onConnected()` flushed queued `debug_log` frames the instant `_state` flipped to `connected` — 15 lines *before* `_sendSessionHello()`.
- Both 4000 (malformed) and 4001 (superseded) were treated as retryable → retry → another 4000/supersede → storm (8 `ws-relay-open` in 30s). Heartbeat 4002-timed-out twice (26.6s, 29.8s) inside the storm.

### Work shipped (7 commits)
1. **`99b96e3`** — `connTrace` signaling instrumentation: timestamped `[HH:MM:SS.mmm] [event] [details]` at login/ws-open/sdp/ice/pc-state/first-frame.
2. **`e07bdb5`** — Build 96 version bump.
3. **`899a075`** — On-device **Connection Diagnostics** viewer (`lib/presentation/screens/settings/connection_diagnostics_screen.dart`) — `connTrace` writes to a 500-entry ring buffer in `conn_trace.dart`; viewer at Settings → Diagnostics with Copy/Share/Clear. Built because the dev workflow has **no Mac/Xcode console** — only an iPhone.
4. **`95f2165`** — Build 97: `NSLocationWhenInUseUsageDescription` added to `ios/Runner/Info.plist` — clears Apple's ITMS-90683 warning (flutter_webrtc links iOS location APIs).
5. **`0631b55`** — **Fix #1**: WS handshake gate. `session_hello` guaranteed first frame; all other frames queue in `_pendingFrames` until inbound `session_ack`; WebRTC frames lossless, `debug_log` lossy under 50-cap; 10s handshake timeout; `expectRelayHandshake` flag exempts local mode (verified `_sessionId` is always non-null — Case A; the dead `_sessionId == null` branch removed).
6. **`07dac1a`** — **Fix #2**: WS close-code handling. `_classifyClose()` → retry only retryable codes; exponential backoff 1s→30s (was linear). Contract: 4000 malformed/permanent, 4001 invalid_token/permanent→re-login, 4002 heartbeat/retryable, 4003 superseded/expected-silent, 1000 clean/no-retry, 1006/null/retryable. New `closeReasonStream`. **Removed the second reconnect engine** in `connection_provider` (it blindly reconnected on every `wsState→error`) — `WebSocketClient` is now the sole reconnection owner. Removed the Build 88 `_suppressSessionHello` hack.
7. **`182dfce`** — **Fix #3**: heartbeat hardened. Cadence already 10s (Build 90). Ping now gated behind `_handshakeComplete`; `_pingTimer` cancelled in `_onDone` so it can't linger on a dead socket; every ping logged via `connTrace('ws-heartbeat')`.

### Relay/robot contract changes coordinated this session
- Relay confirmed `session_ack` already exists — the app gates on inbound `type=='session_ack'` (exact string, session_id echo verified).
- Relay split 4001: now **4001 = invalid_token**, **4003 = session_superseded** (was overloaded). App close-code table matches.
- Post-ack relay frame order (FYI): `session_ack → [session_restored] → auth_result → robot_status → metrics_sync`.

### Verification
- `flutter analyze` clean on every touched file.
- User confirmed on-device: login→video show speed "pretty decent" — ~60s delay gone. Robot session's bet held: no real WebRTC issue was hiding behind the storm.

### New files (2)
- `lib/core/utils/conn_trace.dart` — `connTrace()` + `ConnTraceLog` ring buffer.
- `lib/presentation/screens/settings/connection_diagnostics_screen.dart` — on-device trace viewer.

### Open items / next steps
- **Volume control task — UNFINISHED.** Decisions locked: app switches volume *set* to `POST /audio/volume` (REST, 200 = "syncing…" confirmation); robot adds `volume` to the 5s telemetry payload. **Blocked** on the robot session providing exact JSON shapes (GET response, POST body key, telemetry field name/range, clamp behavior) — a paste-ready request was drafted. Resume here when shapes arrive: add `RobotApi.getVolume/setVolume`, `VolumeNotifier` (`{int? level, bool syncing}`), telemetry `volume` field (+ build_runner), remove `_volumeProvider`'s hardcoded `=>70` in `quick_actions.dart`.
- `.claude/local_notifications.md` — untracked spec for `flutter_local_notifications` (lock-screen/Watch alerts); not implemented.
- Carried from Build 94/95: run `scripts/generate_aruco_markers.py` + uncomment the assets line; file relay ticket for blind `(user_id, device_id)` unpair.
- `connTrace` + Connection Diagnostics screen intentionally left in — the only Mac-free way to diagnose connection regressions. Strip later if desired.
- Trigger Codemagic for Build 97 (manual).

---

## Session: 2026-05-20 — Builds 94 + 95 (Joystick, Secure Auth, ArUco Add-Dog, Pairing Fix, Save Password)
**Goal:** Three user-requested features (analog joystick, password autofill / stored login, add-your-own-dog with ArUco) plus mid-session fixes (manage-pairing escape, silent re-auth bug, save-password polish).
**Status:** Completed — both builds pushed to main. Build 95 building on Codemagic at end of session.

### Build 94 — feat: Build 94 — analog joystick, secure-storage silent re-auth, ArUco add-dog, pairing fix (90c9eeb)

**Drive — virtual analog joystick replaces D-pad**
- New `_MotorJoystick` in `drive_screen.dart` using `flutter_joystick` (already in pubspec). 10% radial deadzone, linear remap above threshold, arcade mix (`left = y + x`, `right = y - x`), 50 ms ticker × 200 ms ramp = 0.25 advance per tick. Y inverted so up = forward. E-STOP badge pinned top-right of base; shows speed % while moving.
- `MotorControlNotifier` cleanup: deleted dead `setFromJoystick`, `stop()`, `_sendCommand`, `_ensureSendTimer`, `_sendTimer`/`_hasPendingCommand`/`_lastSent*`. Down to 3 methods: `setMotorSpeeds`, `_sendCommandImmediate`, `emergencyStop`. Motor wire format unchanged.

**Auth — JWT in Keychain/Keystore, silent re-auth, GoRouter splash gate**
- `flutter_secure_storage: ^9.2.2` added. New `lib/core/storage/secure_token_storage.dart` wraps with `first_unlock_this_device` accessibility on iOS, `encryptedSharedPreferences` on Android.
- `AuthState.bootstrapping` flag added (default true). `_loadSavedAuth` reads JWT from secure storage with one-time migration of legacy SharedPrefs token, calls `/api/auth/validate`, sets state accordingly.
- New `lib/presentation/screens/splash_screen.dart` at `initialLocation: '/'` watches `bootstrapping` and routes to `/home` or `/login`. GoRouter redirect (moved into `_WimzAppState` so it can read Riverpod) pins to `/` during bootstrap and gates `/login` on `isAuthenticated`. `login/register/logout` set `bootstrapping: false` consistently.

**Add Dog — auto-allocate ArUco ID, in-flow marker preview, print to PDF**
- `DogProfilesNotifier.nextFreeArucoId({start=0, end=999})` walks the existing profiles' ArUco IDs and returns lowest unused (implicitly skips Elsa=315 and Bezik=832 because they're in state).
- New `lib/presentation/widgets/aruco_marker_view.dart` loads `assets/markers/aruco_4x4_1000/{id}.png` with graceful `errorBuilder` placeholder when PNG bundle isn't generated yet. Exports `loadArucoMarkerBytes()` for the print path.
- `AddDogScreen` step 3 now: auto-fills next free ID on first entry (idempotent via `_arucoAutofilled` flag), shows live `ArucoMarkerView` preview as the user types, "Print marker" button builds a Letter-size PDF (dog name + ID label + 4″ square marker) via `printing.layoutPdf`. Added `printing: ^5.13.4` and `pdf: ^3.11.1` to pubspec.
- New `scripts/generate_aruco_markers.py` (executable) — one-shot OpenCV script that writes the 1000 DICT_4X4_1000 PNGs. **User must run this once** (`pip install opencv-contrib-python`, then `python scripts/generate_aruco_markers.py`) and uncomment the commented-out `- assets/markers/aruco_4x4_1000/` line in pubspec.yaml to activate the real markers. Until then, the placeholder fallback renders and the print button surfaces a clear "marker bundle not generated" snackbar.

**Pairing — input validation + orphaned-unpair recovery (mid-session add-on)**
- User reported: garbage device IDs got accepted by relay's pair endpoint but the unpair endpoint then returns 404 ("robot not found") because the device row doesn't exist in the relay's registry, leaving orphaned pairing rows the user can't escape.
- Root cause is relay-side (unpair shouldn't require device-exists). App-side mitigation:
  - `device_api.unpairDevice` returns `Future<int?>` (status code) instead of throw-on-4xx so the provider can distinguish 404 from real errors.
  - New `UnpairOutcome { success, orphaned, error }` enum. Per-user SharedPrefs-persisted `_dismissedDeviceIds` set; `loadDevices` filters dismissed IDs out. New `dismissLocally(deviceId)` API.
  - `device_pairing_screen._pairDevice` regex `^[a-zA-Z0-9][a-zA-Z0-9_-]{2,49}$` blocks garbage at the source; on `UnpairOutcome.orphaned`, follow-up "Robot Not Found — Hide?" dialog calls `dismissLocally`.
  - `settings_screen` swipe-to-dismiss auto-falls-back to `dismissLocally` on orphaned (user already confirmed via swipe).
- File a relay-side ticket: unpair should delete by `(user_id, device_id)` blindly.

### Build 95 — fix: Build 95 — silent re-auth fail-open, save-password prefill (9a1041f)

**Silent re-auth bug (user reported on Build 94 TestFlight: "logged in, closed app on iOS, asked to login again")**
- Root cause: Build 94's `validateToken` returned `bool` (true only on 200), and `_loadSavedAuth` deleted the JWT on *any* non-200 — including transient 5xx, cold-start timeouts, DNS hiccups, etc.
- Fix: `validateToken` now returns `TokenValidation { valid, invalid, unreachable }`. `_loadSavedAuth` only clears the JWT on a definitive `invalid` (401/403). On `unreachable` (5xx, network error, timeout), trust the locally-stored token and log the user in optimistically — any downstream 401 will land them on `/login` anyway, but a flaky relay no longer costs them a stored session.
- Added print logs at each step (`Auth: no stored JWT — showing login`, `Auth: /validate → valid/invalid/unreachable`, `Auth: relay rejected JWT — clearing...`, `Auth: /validate unreachable — restoring session optimistically`) for next-time diagnosis via Xcode Console.

**Save Password (user followup: "have a save password checkbox which is what I thought we were going to have")**
- `SecureTokenStorage` extended with `readPassword/writePassword/deletePassword`. Keyed separately from the JWT.
- `LoginScreen` `_loadSavedCredentials` now pulls both email (SharedPrefs, existing) and password (secure storage) on mount and prefills both controllers.
- New "Save password" checkbox below the password field, default ON. On submit, password written to secure storage when checked, deleted when unchecked.
- `_clearAuth` (logout path) now wipes the saved password too — explicit "next user starts clean" semantics.

### Coordinated decisions (with the user)

1. **Q1 joystick mechanism** → virtual on-screen joystick (replace D-pad), phone-only. Not hardware gamepad.
2. **Q2 auth storage** → JWT in secure storage + `/validate` on launch (NOT password storage). Build 95 added the password-save layer on top.
3. **Q3a ArUco dictionary** → DICT_4X4_1000 (matches robot vision pipeline).
4. **Q3b ArUco allocation** → app allocates (not relay). Single-user single-device, races are theoretical.
5. **ArUco render approach** → bundled PNGs via one-shot OpenCV Python script. NOT pure-Dart dictionary table (would need to transcribe ~4KB of OpenCV byte data unavailable in session) and NOT external generator (user wanted in-app flow).
6. **Pairing dismiss storage** → app-side SharedPrefs (user: "relay can have garbage").
7. **Build 95 vs hold on autofill** → user confirmed: bypass login when previously logged in, AND have password ready when login does show. Both shipped.

### Commits this session
```
9a1041f fix: Build 95 — silent re-auth fail-open, save-password prefill
90c9eeb feat: Build 94 — analog joystick, secure-storage silent re-auth, ArUco add-dog, pairing fix
```

### Files modified
- Build 94: 13 modified, 4 new (`splash_screen.dart`, `secure_token_storage.dart`, `aruco_marker_view.dart`, `scripts/generate_aruco_markers.py`). 887 insertions, 340 deletions.
- Build 95: 5 modified. 110 insertions, 17 deletions.
- Version: 1.0.0+93 → 1.0.0+94 → 1.0.0+95.
- New deps: `flutter_secure_storage`, `printing`, `pdf`.

### Verification
- `flutter analyze` on every touched file: clean. Remaining lints (`prefer_const_constructors`, `withOpacity` deprecation infos) are all in pre-existing untouched code.
- No device testing performed in this session (WSL environment) — user shipped to TestFlight via Codemagic.

### Open items / followups
- **User must run `scripts/generate_aruco_markers.py`** and uncomment the assets line in `pubspec.yaml` to activate real ArUco marker PNGs. Until then, the AddDogScreen flow works end-to-end but shows a placeholder marker and the print button surfaces a "bundle not generated" snackbar.
- **File relay-side ticket**: `POST /api/user/unpair-device` should delete by `(user_id, device_id)` without requiring the device row to exist. App-side dismissed-list is a workaround.
- **Verify Build 95 silent re-auth on device**: user to grab `Auth:` lines from Xcode Console after TestFlight install if cold-launch still bounces to /login. Will tell us which branch fires.
- **Manual UI verification** still needed: joystick feel, add-dog ArUco flow with real PNGs, pairing escape on the existing stuck entries, password prefill across logout/reinstall.

---

## Session: 2026-04-27 — Build 93 (Coach Mode Exit Unified on `set_mode(idle)`)
**Goal:** User-reported bug: in-screen "Stop Coaching" button does nothing. Diagnose, coordinate with robot session, fix.
**Status:** Completed — pushed to main (Build 93: 031f1e5)

### Root cause
The cloud-relay path the app uses had no working handler for `stop_coach`. The home-screen EXIT button worked because it routes through `set_mode(idle)`, which hits the robot's mode-change handler — the single source of truth for coach teardown via `engine.stop()`. Build 38's "send `stop_coach` only, don't duplicate with `set_mode`" design assumed a robot handler that either never existed on the cloud path or got removed.

### Coordinated decision (with robot session)
Unify all coach teardown on `set_mode(idle)`. Delete the dedicated `stop_coach` / `start_coach` / `coach_set_behaviors` handlers robot-side; app stops sending them. Robot's mode-change handler at `main_treatbot.py:1786` becomes the only teardown path.

### App-side changes (Build 93: 031f1e5)

**`lib/domain/providers/coach_provider.dart`**
- `stopCoaching()` now calls `setMode(RobotMode.idle, source: 'coach_exit')` instead of sending `stop_coach`. Reverses Build 38 with updated comment.
- `startCoaching()` simplified: only `setMode(RobotMode.coach)` + local state update. Dropped the dead `start_coach` WS send and the `dogId` / `anyVisibleDog` params (their payload was always silently discarded — robot reads dog identity from ArUco vision, not from app payload).
- `setBehaviors()` deleted entirely (no robot handler ever existed; TRICKS is loaded once at engine construction with no runtime mutation API).
- Listener `coach_started` → `coaching_started`; reads `tricks_available` instead of `behaviors` (canonical robot event per `coaching_engine.py:259-261`).
- Listener `coach_stopped` replaced with `mode_changed` — when new mode != `'coach'` and `isActive`, flip off.
- `CoachState.watchingFor` doc updated: now read-only mirror of robot's `tricks_available`.
- Removed unused `dog_profiles_provider` import.

**`lib/presentation/screens/coach/coach_screen.dart`**
- Removed duplicate top-right red ⏹ icon (was lines 153–160).
- Renamed bottom button "Stop Coaching" → "Exit Coach Mode"; on tap, calls `stopCoaching()` then `context.pop()`.
- Back arrow now also calls `stopCoaching()` before popping (was a no-op per Build 38). Leaving the screen by any path = exiting coach mode.

### Robot-side decisions (theirs to execute)
- Delete `start_coach` / `stop_coach` branches in `main_treatbot.py:1491-1509` (already no-ops on the cloud path).
- Delete `start_coach` / `stop_coach` from `api/ws.py:611-630` (local WS, redundant — app doesn't use this path).
- Mode-change handler stays — already handles teardown correctly.
- No guard needed for `coach_set_behaviors` warnings; once Build 93 deploys, app stops sending it and the warning disappears naturally.

### Architectural decisions locked in
1. **`set_mode` is the only coach lifecycle primitive.** No dedicated start/stop commands.
2. **`watchingFor` (TRICKS list) is robot-side configuration**, broadcast via `tricks_available` on `coaching_started`. App treats as read-only.
3. **Coach dog targeting is pure-vision** (ArUco-first + longest-visible per `coaching_engine.py:547-573`). App makes NO targeting calls on coach entry.
4. **`select_dog` (Build 91, global) ≠ `force_dog` (coach-only).** `select_dog` is for voice/profile routing only — coach engine doesn't read it. `force_dog` exists but is the wrong primitive (renames every visible dog to the forced name) — explicitly NOT auto-fired by app.
5. **Future "coach picked wrong dog" need:** robot will add a clean `pin_session_dog` WS command (filter eligible dogs without renaming). Not built; file separately if it becomes a real complaint.

### Verification
- `flutter analyze --no-pub lib/domain/providers/coach_provider.dart lib/presentation/screens/coach/coach_screen.dart` → 0 errors (14 pre-existing `withOpacity` deprecation infos, all unchanged from before).
- No remaining `setBehaviors` / `coach_set_behaviors` / `coach_started` / `coach_stopped` / `stop_coach` / `start_coach` references in `lib/`.

### Commits
```
031f1e5 fix: Build 93 — unify coach mode exit on set_mode(idle), drop dead WS commands
```

### Files modified (3)
- `lib/domain/providers/coach_provider.dart` (gutted dead WS sends, renamed listener)
- `lib/presentation/screens/coach/coach_screen.dart` (Exit button + back-arrow teardown)
- `pubspec.yaml` (1.0.0+92 → 1.0.0+93)

### Next session / open items
- **Codemagic build trigger** for Build 93 (manual).
- **Verify robot deploy** has actually deleted the `start_coach` / `stop_coach` / `coach_set_behaviors` handlers — until they do, the app's silence is benign but the cleanup isn't symmetric.
- **Bug to watch for:** if a user enters coach mode with a globally-selected dog and there are multiple dogs visible, robot picks via ArUco-first + longest-visible heuristic, not user selection. If complaints arrive, file `pin_session_dog` request to robot session.
- **Coach screen `setBehaviors` UI:** there's currently no UI surface for editing `watchingFor`, but if any was planned, it can't be implemented app-side — needs a robot-side runtime TRICKS mutation API.

---

## Session: 2026-04-25 — Build 87 (Cross-Device Restore + Session Identity + Multi-Dog + Per-Type Notifications)
**Goal:** Coordinated 3-codebase change for cross-device data restore, WebRTC session lifecycle fix, multi-dog data model, per-type notification routing
**Status:** Completed — pushed to main (Build 87: 01ae7a1). Plan file: `~/.claude/plans/ok-first-just-explain-curried-swing.md`

### Coordinated with sister codebases
- **Relay** (head 249567b deployed to Lightsail): all 3 phases shipped — Phase 1 9766be1 (B2 sessions + A1 dogs), Phase 2 6df5595 (A2 voice commands), Phase 3 249567b (A3 activity log).
- **Robot** (Pi): C0 duplicate-detection fix shipped (`core/dog_tracker.py` lines ~152, ~213, ~459 with new `_find_overlapping_tracked_dog` + `_bbox_iou` helpers). Build 38 gap, not a regression — generic + ArUco entries were never deduped. All 5 verification scenarios pass.

### App-side (this codebase) — Build 87 changes

#### Workstream A — Cross-device restore on login
| Change | Files |
|---|---|
| A1: GET /api/dogs hydration with updatedAt-based merge, backfill of local-only profiles | dog_profiles_provider.dart, robot_api.dart, dog_profile.dart (+freezed) |
| A2: Voice command relay-mediated upload (multipart) + manifest GET + WAV download on hydrate; WS upload_voice kept as local-mode fallback | voice_commands_provider.dart, robot_api.dart, voice_command.dart (+freezed) |
| A3: GET /api/activity (last 7 days) merged into in-memory feed with relay→app event-type mapping | notifications_provider.dart, robot_api.dart |
| Auth chaining: dogs → voice commands per dog → activity hydration on _loadSavedAuth/register/login. Best-effort, never blocks login. | auth_provider.dart |

#### Workstream B — Session identity + lifecycle hardening
| Change | Files |
|---|---|
| B1 SessionId per launch (UUID, regenerated on connect) | NEW: lib/core/session/session_id.dart |
| B1 session_hello first-frame handshake; session_id tag on all WebRTC signaling; session_superseded inbound stream → ConnectionStatus.superseded with takeOverSession() | websocket_client.dart, connection_provider.dart |
| B4 detached lifecycle handler (best-effort client_closing + WebRTC teardown + WS disconnect); paused-30s background-teardown timer; resumed → hardTeardown if WS dead before reconnect | app.dart, webrtc_provider.dart |
| B4 WS ping interval 30s → 10s | app_constants.dart |

#### Workstream C — Multi-dog data model (Option 3, ArUco-only; visual ID deferred)
| Change | Files |
|---|---|
| C2 start_mission/start_coach accept optional dog_id | missions_provider.dart, coach_provider.dart |
| C4 dogAnalyticsProvider filters strictly by event-source dog_id (was incrementing globally — misattribution bug fixed); allDogsAnalyticsProvider added for fleet aggregates | analytics_provider.dart |
| C5 Detection.dogId + trackKey; allDetectionsProvider (TTL-pruned map); coach_screen renders one _DogChip per visible dog with palette-hashed per-dog color; MultiDetectionOverlay added | telemetry.dart (+freezed), telemetry_provider.dart, coach_screen.dart, detection_overlay.dart |
| ConnectionStatus.superseded → connection_badge case | connection_badge.dart |

#### Per-type notifications (added mid-session)
| Change | Files |
|---|---|
| NotificationChannel enum (off/inApp/inAppAndPush) persisted as JSON map keyed by NotificationEventType. AppSettings.channelFor(type) with sensible defaults | settings_provider.dart |
| notifications_provider.addNotification consults channel: off drops entirely, inApp adds to feed only, inAppAndPush also fires OS notification (which iOS mirrors to Apple Watch) | notifications_provider.dart, notification_service.dart (shouldNotify deprecated) |
| NotificationPreferencesScreen at /settings/notifications with per-type SegmentedButton + master switch + reset-to-defaults | NEW: notification_preferences_screen.dart, settings_screen.dart, app.dart |

### Files created (2)
- `lib/core/session/session_id.dart`
- `lib/presentation/screens/settings/notification_preferences_screen.dart`

### Files modified (29)
lib/app.dart, lib/core/constants/api_endpoints.dart, lib/core/constants/app_constants.dart, lib/core/network/websocket_client.dart, lib/core/services/notification_service.dart, lib/data/datasources/robot_api.dart, lib/data/models/dog_profile.dart (+gen), lib/data/models/telemetry.dart (+gen), lib/data/models/voice_command.dart (+gen), lib/domain/providers/{analytics,auth,coach,connection,dog_profiles,missions,notifications,settings,telemetry,voice_commands,webrtc}_provider.dart, lib/presentation/screens/coach/coach_screen.dart, lib/presentation/screens/settings/settings_screen.dart, lib/presentation/widgets/status/{connection_badge,detection_overlay}.dart, pubspec.yaml

### Verification
- `flutter analyze --no-pub lib`: **0 errors** (388 info/warning, all pre-existing or unrelated deprecation hints)
- `dart run build_runner build --delete-conflicting-outputs`: 974 outputs, succeeded

### Architectural decisions locked in this session
1. **Option 3** for multi-dog: true multi-dog data model now (every event tagged with stable `dog_id`); visual ID (face/feature embedding) explicitly deferred to a future epic. Not part of this plan.
2. **Voice command audio bytes** live in relay file/object storage (`/api/voice-commands/file/{user}/{dog}/{cmd}` — no auth on download, URL is the security boundary), fetched on demand. Mirrors `/api/music/upload`.
3. **Per-type notification channels** rather than a single global toggle. Defaults chosen to keep Watch/lock-screen quiet for high-frequency types (bark, behavior detections) while pushing high-signal events (treat dispensed, coach reward, mission completed, alerts).
4. **Profile deletion** confirmed already wired end-to-end (relay DELETE + robot delete_dog WS + local + selectedDog clear). Cross-device delete propagates via relay being source of truth.

### Known limitations / next steps
- **Visual dog ID** is the major deferred epic — when ArUco is occluded and no in-session prior identification exists, robot labels "Unknown" (dog_id=null). Future work: face/feature embedding on Hailo-8.
- **Token storage** still in plain SharedPreferences. Worth migrating to FlutterSecureStorage in a follow-up.
- **Photos** still local-only; not in this plan's scope.
- **Settings** (motor trim, daily limit, host/port) still app-local; intentional.
- **Testing**: Phase 1 verification (session supersede, force-quit recovery, reinstall dogs); Phase 2 (reinstall voice); Phase 3 (reinstall activity, two-dogs-in-frame, per-dog voice playback, per-dog analytics) — runtime testing on iOS device + robot still required. Plan doc has the full verification matrix.
- **Codemagic**: Build 87 ready to trigger.

### Commit
```
01ae7a1 feat: Build 87 — cross-device restore, session identity, multi-dog data, per-type notifications
```

### Coordination context for next session
The orchestration model from this session worked well:
- This (app) Claude as the master, drafting paste-ready prompts for the relay and robot Claudes.
- Plan file at `~/.claude/plans/ok-first-just-explain-curried-swing.md` has the full coordinated plan including paste-ready prompts for relay and robot.
- Next person/session: hand the relay's deployed-to-Lightsail commit (249567b) and the robot's C0 fix as known-good baselines. Any follow-up that touches all three repos should reuse the orchestrator pattern from this session.

---

## Session: 2026-04-01 — Builds 65-66 (PTT Logging, Treat UI, Trick Sync, Local Mode, WiFi Config)
**Goal:** PTT debug logging, treat carousel updates, trick name alignment with Pi, local connection mode, WiFi config UI
**Status:** Completed — pushed to main (Build 66: ef1b372)

### Build 65 (6a04109) — PTT Logging, Treat UI, Trick Alignment, Local Mode
| Change | Description |
|--------|-------------|
| A1: PTT Debug Logging | Added `[PTT]` prefixed print() at every pipeline stage: button press/release, mic start/stop, packet size, send latency measurement |
| A2: Treat Refill → 44 | `resetCount()` now sends `treat_counter_set(44)` instead of parameterless reset. Button shows "Reset to Full (44)" |
| A2: Clear Jam Button | New button in treat bottom sheet — sends `carousel_rotate` command with 2s "Clearing..." loading state |
| A3: Trick Name Alignment | Coach defaults changed to `['sit','laydown','come','spin','speak']` matching Pi's canonical list |
| A3: down → laydown | Renamed `down`/`lie_down` → `laydown` in coach_provider, missions_provider, voice_command, app_theme, notifications_provider |
| A3: New Display Names | Added Spin → "Spin", Speak → "Speak", fixed come vs stand mapping |
| A3: New Missions | Added `laydown`, `come_training`, `spin_training` mission definitions |
| A4: Local Mode Toggle | Settings screen toggle with IP/port fields, connect/disconnect buttons, uses LocalConnectionService for direct ws:// |
| A4: Helper Text | "Find robot's IP on boot screen or run: hostname -I" |

### Build 66 (ef1b372) — WiFi Config UI (from separate session)
| Change | Description |
|--------|-------------|
| WiFi Endpoints | Added `/system/wifi/scan`, `/system/wifi/connect`, `/system/network-status` to api_endpoints |
| WiFi API Methods | `wifiScan()`, `wifiConnect()`, `networkStatus()` in robot_api.dart |
| WiFi Config Provider | New `wifi_config_provider.dart` — scan, connect, network status polling |
| WiFi Config Sheet | Bottom sheet in local mode: scan networks, select SSID, password entry, connection status flow |
| Network Status | Indicator showing AP vs WiFi mode when connected locally |

### Key Architecture Notes:
- **Local mode WebRTC**: App side is complete — all signaling goes through WebSocketClient singleton. Pi's local WS handler must process `webrtc_request/answer/ice` messages.
- **Local mode PTT**: Works — sends `ptt_play` command via WebSocket (base64 WAV), does NOT use WebRTC audio track for sending.
- **Trick canonical names**: Pi uses `sit`, `laydown`, `come`, `spin`, `speak`. App now matches.
- **Treat full count**: 44 treats = full carousel (was undefined/robot-decided, now explicit).

### Files Modified (Build 65 — 11 files):
- push_to_talk_provider.dart, control_provider.dart, coach_provider.dart, missions_provider.dart, notifications_provider.dart, settings_provider.dart, voice_command.dart, settings_screen.dart, app_theme.dart, treat_counter_indicator.dart, pubspec.yaml

### Files Modified/Created (Build 66 — 5 files):
- api_endpoints.dart, robot_api.dart, settings_screen.dart, pubspec.yaml
- NEW: wifi_config_provider.dart

### Unresolved / Next Steps:
1. Pi-side: Local WS handler needs `webrtc_request/answer/ice` support for local video streaming
2. Pi-side: Local WS handler needs `ptt_play` command support
3. Coach stats still session-only (not persisted across app restarts)
4. `dogDailySummaryProvider` still mock data
5. Video download only works on LAN — relay needs media endpoints for WAN

---

## Session: 2026-03-22/23 — Builds 61-63 (PP Fixes, Coach Stats, Profile Sync)
**Goal:** Fix PTT, video recording, mission mode, coach detection, unknown dog prompt, daily limit, profile sync
**Status:** Completed — pushed to main (Build 63)

### Problems Solved This Session:

#### Build 61 — Major Feature/Fix Bundle (445d0e8)
| Fix | Description |
|-----|-------------|
| A1: PTT Redesign | Tap toggle (not hold), 5s max, countdown inside button, "Sent" confirmation |
| A2: Video Timeout | Increased to 45s, detailed logging, handle video_ready event |
| A3: Mission Exit | Always exits to idle (not restore previous portrait mode) |
| A4: Coach Detection | Dog name from WS events (not profile), Detection model gains dogName/arucoId |
| Coach Stats | coach_reward events → analytics, notifications, dashboard, dog profile metrics |
| Unknown Dog Prompt | unknownDogProvider + yellow banner on home screen → navigate to add dog with arucoId |
| Daily Limit Toggle | Optional daily treat limit in settings, sends mission_config to robot |
| Drive Exit Mode Fix | storePortraitMode reads telemetry (not stale cached currentMode) |

#### Post-Build 61 Fixes
| Commit | Fix |
|--------|-----|
| 4f0f11a | Align with robot API: mission_config command, unknown_dog_detected event |
| db7a2fd | ArUco false positive notifications filtered, mission STOP button on drive, treat counter in settings uses provider, coach dog selection from detection |
| 85eee1f | Mission error handling — don't navigate to drive until robot confirms start, show error snackbar |
| 6c16d47 | Video recording uses download URL (not base64 blob), HTTP download with progress |
| d8ec7bc | Video sends record_video command (not start_recording) — root cause of robot never recording |
| 4c252ef | PTT countdown number shown inside button (was hidden in compact mode) |
| 149dcc5 | User-friendly video download error messages (not raw DioException) |
| db214ae | Sync dog profiles to robot via reload_dogs with full profile data on connect/add/update/delete |
| ca139d5 | Fix race condition: sync profiles after async SharedPreferences load completes |

### Key Architecture Changes:
- **Video flow**: App sends `record_video` (with duration) → robot records → sends `video_ready` with `download_url` → app downloads MP4 via HTTP → saves to gallery. No more base64 over WebSocket.
- **Profile sync**: App pushes all dog profiles to robot on connect and on any profile change via `reload_dogs` command with profiles array. No relay dependency.
- **Mission start**: App no longer navigates to drive immediately. Uses `ref.listen` to wait for robot confirmation, shows "Starting..." spinner, handles `mission_error` events.
- **Coach mode**: Dog name comes from detection events (ArUco), not selected profile. `start_coach` includes dog_id/dog_name.

### Files Modified (23+ files across session):
Key files: websocket_client.dart, video_provider.dart, video_service.dart, push_to_talk.dart, push_to_talk_provider.dart, mode_provider.dart, missions_provider.dart, mission_detail_screen.dart, dog_profiles_provider.dart, coach_provider.dart, coach_screen.dart, notifications_provider.dart, analytics_provider.dart, settings_provider.dart, settings_screen.dart, home_screen.dart, drive_screen.dart, telemetry_provider.dart, telemetry.dart, notification_event.dart, activity_dashboard.dart, notifications_screen.dart, dog_profile_screen.dart, add_dog_screen.dart, detection_overlay.dart, app.dart

### Unresolved / Next Steps:
1. Video download only works on LAN — relay needs `/api/media/upload` + `/api/media/download` endpoints for WAN
2. Coach stats are session-only (not persisted across app restarts) — needs SharedPreferences or API
3. `dogDailySummaryProvider` is still mock data
4. Daily limit slider sends `mission_config` to robot — needs testing with robot's new handler

### Robot-Side Fixes Applied This Session (not app code):
- `detector.ai.dog_tracker.update_valid_ids()` — was using wrong attribute path `ai_controller`
- `record_video` command handler added with duration/resolution
- `video_ready` event with `download_url` field
- `reload_dogs` now accepts profiles array directly, persists to SQLite
- `mission_error` event with user-friendly `message` field

---

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
