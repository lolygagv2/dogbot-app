# WIM-Z Resume Chat Log

## Session: 2026-06-06 — Builds 125–126 (real data, unified SG history, local profiles, robot guardian contract)
**Goal:** User frustrated with beta regressions. Three reported defects, treated as a "fix everything now, no to-be-continued" mandate: (1) Silent Guardian history doesn't load when reopening the app after backgrounding for hours; (2) the events shown are FAKE; (3) local-mode dog profile vanishes on app close.
**Status:** ✅ All app-side fixes shipped (Builds 125 + 126), pushed to `origin/main` (synced). Backend (robot + relay) confirmed live by their Claude instances. Feature is closed end-to-end pending on-device verification + a runtime-captured escalation payload.

### Root cause (shared across all three)
App state was silently scoped to a cloud-auth identity that local mode doesn't have, AND mock data was wired at provider-CONSTRUCTOR level (not behind `isDemoMode`) — which **masked** the real bugs: the fake events were stamped `now()` so the feed was never visibly empty, so every "did history load?" check looked fine. Removing the mock is what made the real bug visible. (Saved to memory: [[fake-data-masked-bugs]], [[work-style-fix-completely]].)

### Build 125 (commit `b3e8bf5`) — app
1. **Ripped out all fake data:** deleted `_generateMockData()` (14 fake notifications); `dogDailySummaryProvider` 5/3/12 → real today aggregation; `dogWeeklyStatsProvider` `Random()` chart → real 7-day aggregation; `setRange()` ×7/×30 → real today/week/lifetime; removed debug "Add Test Event" button. Fixed a replay bug where buffered events were stamped `now()`/fresh-id (broke ordering + dedup) → now keep `ts_server` time + stable id.
2. **Unified the two event lists:** `notificationsProvider` is the single history source; `guardianEventsProvider` is now a PROJECTION of it (alert→alertTriggered etc.). The SG feed gets the same live + REST + store-and-forward as the Activity tab. Removed its independent WS subscription.
3. **Hydrate on RESUME, not just login:** `connection_provider.onAppResumed()` now calls `notificationsProvider.hydrateFromRelay()` — fixes the 2-hour-gap. (Self-skips in local mode / no token.)
4. **Local-mode profiles:** stable `'local'` storage scope (independent of cloud email) + one-time `anonymous`→`local` migration + `reloadForCurrentUser()` on local connect. `SelectedDogNotifier` uses the same scope.
- New file: `lib/data/models/activity_aggregation.dart` (real summarize helpers). New: `.claude/BACKEND_BRIEF_2026-06-06.md`. Bumped `pubspec` → `1.0.0+125`. Also committed the previously-staged pairing auto-select fix (`paired_devices_provider.dart`).

### Backend (other Claude instances — confirmed live)
- **Robot (commit `c17c0cd`, deployed to treatbot5):** barks now carry `dog_id`/`dog_name`; SG events forwarded as `{event:'guardian', action: started|stopped|escalation|reset}`; every relay event gets uuid4 `id` + ISO8601-UTC `timestamp` (via setdefault, doesn't clobber existing). Robot is now authoritative for id+timestamp. **Caveat:** could NOT live-fire a real bark/escalation (needs a barking dog) — those two runtime payloads are inferred, not captured.
- **Relay:** confirmed set (durable persist + `GET /api/activity`). Relay maps `event`→`type`.

### Build 126 (commit `3dfae46`) — app, responding to robot contract
The app had NO `guardian` case, so the robot's new guardian events arrived (via WS `default` route + from REST) and were **silently dropped** — same masking trap. Fixed:
- `notifications_provider._handleWsEvent`: added `case 'guardian'` → `_guardianNotification()`. Lifecycle actions (start/stop/reset) skipped; escalation/intervention → alert. Action normalized defensively (strips `sg_`/`silent_guardian_`) since exact escalation string is inferred.
- REST `_activityEventToNotification`: added `case 'guardian'` (action read from payload or top-level).
- Bark live path now carries `dog_id` → per-dog stats attribute it.
- Bumped `pubspec` → `1.0.0+126`.

### Explicitly OUT of scope (flagged, not silent)
- **True background push (FCM/APNs)** — app only has `flutter_local_notifications` (fires while app process alive). Real "ping while app killed" needs FCM/APNs + relay push service + device-token registration. Separate future track. User chose in-app-history-only this pass.

### Next session
1. **On-device verify Build 126** (watch Codemagic publish; manual APK if post-processing fails — [[codemagic-publish-trap]]). Order: `login-connect` canary present → Activity tab starts EMPTY (no "Max earned a reward") → start SG, generate a bark, background 2+ min, reopen → events show in SG feed + Activity → add dog in local mode, close, reopen → dog persists.
2. **Get robot Claude to synthesize a fake bark/escalation onto the bus** and capture the exact payload, so the inferred `action`/field names are confirmed (one-line app fix if they differ). Robot Claude offered this.
3. Carry-overs still open: store-and-forward E2E, password-reset E2E, per-robot servo calibration, Codemagic→Play auto-publish.

---

## Session: 2026-06-03/04 — Builds 121–124 (Android relay-connect fix + issue triage)
**Goal:** "Android app logs in, reaches main menu, says server disconnected." Cloud relay is useless without it. Then a follow-up list: center button (local), no detection boxes (local), signup broken, push-to-talk (Android).
**Status:** ✅ Root cause found and fixed; validated on-device. All app-side items resolved or triaged. Builds 121→124 pushed to `origin/main` (synced).

### The big one — Android relay connection (FIXED, Build 123)
Symptom: `login-success` then a webrtc retry loop, "disconnected"; iOS worked fine on both fresh login AND reopen. Long hunt (I was wrong on cert-chain, `/health`, and a GoRouter-redirect theory — all ruled out by direct testing).
**Real cause:** `auth_provider.login()` set auth state, fired `login-success`, then `await dogProfilesProvider.reloadForCurrentUser()` — which **threw on Android**, so `login()` returned false, so `login_screen`'s `if (success && mounted)` post-login block (which called `connect()`) was **skipped** → relay WS never attempted. iOS didn't hit the throw.
**Fix:** new `AuthNotifier._connectRelay(scenario)` connects to the relay from the provider (default host→prod when none saved), called from `login()`/`register()`/silent-reauth **before** the dog reload, and the reload is now wrapped so it can't unwind auth. `login_screen` no longer connects (avoids iOS double-connect). Build 122 added the silent-reauth default-host fallback; Build 121 added `conn_trace` instrumentation across the connect→WSS blind spot (`conn-begin`, `health-ok`, `ws-connect-attempt`, `ws-connect-error`, `login-connect`).
**Validated:** on-device log showed `login-connect → conn-begin → health-ok → ws-connect-attempt → ws-relay-open → ws-session-ack → ws-heartbeat`, Settings "Server connected."

### THE meta-blocker — stale builds (cost most of the session)
Codemagic build `index 149` = "finished with **post-processing failed**", commit `40b46f0`. Compile succeeded, **Play publish failed**, so the device ran **pre-121 code under a "123" label** the whole time → every "installed it, nothing changed" was a dead end. Proven by the on-device log showing `ws-relay-open` with NO `conn-begin`/`login-connect` (impossible in new code). Likely cause: Google Play "first release must be created manually" rule. Workaround that worked: download APK artifact from Codemagic → manual upload to Play release → install. **Lesson saved to memory** ([[codemagic-publish-trap]]): verify the device is running current code via a canary trace BEFORE debugging app logic.

### Issue triage
- **① Center button (local/AP):** ✅ FIXED Build 124. Was sending `servo_center`, which the robot's local handler doesn't implement; now sends `servo {0,0}` (the command the D-pad uses — confirmed working locally) + `servo_center`.
- **② Detection boxes (local):** ⛔ NOT FIXABLE. No `detection` events arrive in local mode (user confirmed: no chips, no boxes). No relay in local mode + **robots frozen in beta** → dead end. Works in cloud. Leave off.
- **③ Signup:** 🛰️ RELAY bug — `POST /api/auth/register` → HTTP 500 (direct-tested). Brief handed to relay Claude; user ran a relay update — **VERIFY register returns 200 on next build.**
- **④ Push-to-talk (Android):** ✅ resolved — it was the dead relay WS (PTT sends audio over WS); worked once real code connected.

### Builds
```
4c0d63d Build 124 — camera center works in local/AP mode
40b46f0 Build 123 — connect to relay from auth provider, not login screen (THE fix)
401f378 Build 122 — silent re-auth always connects (default host fallback)
1614823 Build 121 — conn_trace diagnostics across the connect→WSS blind spot
```

### Constraints learned
- **Robots are FROZEN (beta) — only app + relay/server can change.** ([[robot-frozen-local-ap-limits]])
- No console for installed builds — debug via Settings → Connection Diagnostics (`conn_trace`). ([[debug-via-in-app-diagnostics]])
- Relay auth API drifted: register 500, no `user_id` in token (app uses JWT `sub`), `/api/auth/validate` 404. ([[relay-auth-contract-drift]])

### Post-session addendum (2026-06-04)
- ✅ **Signup confirmed working on-device** (relay register-500 fix landed — new account created).
- 🟡 **UNCOMMITTED working-tree fix** (Build 125, not yet committed/built — user chose to batch it with the next change): `lib/domain/providers/paired_devices_provider.dart` — `pairDevice()` now calls `setDeviceId(deviceId)` after pairing so the just-paired robot becomes the ACTIVE device. Without it, a freshly-paired robot (esp. first on a new account) left the app on the `wimz_robot_01` placeholder → "Device not paired" until the user manually selected the robot. Long-standing bug, finally fixed. **COMMIT THIS with the next batch — don't lose it / don't `git checkout` that file.**

### Next session
1. **Commit the uncommitted pairing fix above** (bump to +125) with the next batch of changes.
2. **Verify Build 124 on device** (watch the publish step — manual APK if post-processing fails again). Confirm: `login-connect` canary present, center button recenters in local mode, **signup creates an account** (relay fix — already confirmed working).
2. **Fix the Codemagic→Play auto-publish** so manual uploads aren't needed (the manual release may have unblocked it).
3. Carry-overs from prior sessions still open (store-and-forward E2E, password-reset E2E, per-robot servo calibration).

---

## Session: 2026-05-31 — Build 115 (local-AP video fixes: MJPEG endpoint + LAN cleartext)
**Goal:** User reported Phone→Robot local-AP connection is broken: can now log in + connect + give commands, but (a) video says "connecting" forever, (b) connection feels shaky/unresponsive, drops after ~2 commands, and the AP "WIMZ-Demo" never comes back. Robot Claude suggested checking the app's MJPEG fallback URL.
**Status:** ✅ App-side fixes committed `7329fb4` AND pushed to `origin/main`. pubspec `1.0.0+115`. Analyzer-clean. **BUT the real show-stopper is robot-side (R-AP-1) — see below — so video can't be fully verified until that's fixed.**

### Root-cause split (robot-Claude's 4 checks, verified against real code)
1. **MJPEG URL — 🔴 WRONG (fixed).** App was pinned to legacy `/camera/stream`; robot now serves `/video/feed`. Fix: `local_connection_service._resolveMjpegUrl()` PROBES `/video/feed` then `/camera/stream` at connect, stores whichever returns 200 as `LocalConnectionData.mjpegUrl`; `smart_video_view` reads that instead of the hard-coded const (falls back to const if unresolved). Endpoint rename can't silently 404 again.
2. **Fallback trigger — ✅ already fine.** Local mode SKIPS WebRTC entirely — `smart_video_view.initState` sets `_useMjpegFallback=true` immediately when `localModeEnabled`. So "connecting forever" was the **MJPEG feed itself failing** (wrong path + cleartext block), NOT a WebRTC hang. Shortened the user-initiated "Try WebRTC" give-up 10s→6s anyway (no STUN/TURN on AP → ICE never connects).
3. **Base URL on robot wifi — ✅ already fine.** `connectDirect` points Dio + WS at `192.168.4.1:8000`, not relay.
4. **Cleartext block — 🔴 REAL GAP (fixed).** Neither platform allowed plain `http://` — silently kills MJPEG, looks like "connecting forever." Android: NEW `android/app/src/main/res/xml/network_security_config.xml` (scoped to 192.168.4.1 + 192.168.0/1.x + 10.0.0.x, NOT global) + manifest `networkSecurityConfig` ref. iOS: `NSAppTransportSecurity/NSAllowsLocalNetworking` (ATS stays on for relay HTTPS) + `NSLocalNetworkUsageDescription` for the iOS 14+ LAN prompt.

→ TWO independent app bugs each sufficient to kill local video: wrong endpoint AND cleartext blocked. Both fixed.

### 🔴 The actual show-stopper is ROBOT-SIDE (R-AP-1) — brief written
User's timelog shows the robot **kills its own AP ~1s after the phone associates**:
```
17:31:43 Phone associates → SAME SECOND: "WiFi monitor: Attempting to reconnect to known networks" + "Stopping hotspot..."
17:32:08 AP down, home-wifi rejoin FAILS ("A 'wireless' setting is required")
17:33:13 user power-cycled
```
A Pi connectivity watchdog treats "no internet/not on known network" as a fault and tries to rejoin known wifi — which tears down the hotspot (single radio can't AP+STA at once). Fires the instant a client connects → every successful connection triggers AP teardown. That's the "shaky," "dropped after 2 commands," "AP never came back." App CANNOT fix an AP the robot dismantles. Wrote **`.claude/ROBOT_ISSUES_2026-05-31.md`** (NEW): R-AP-1 (gate wifi-monitor on `hotspot_active`, never tear down AP while STA associated — CRITICAL), R-AP-2 (confirm `/video/feed` multipart contract), R-AP-3 (WebRTC-on-AP expected-dead, app handles it).

### Files changed (commit `7329fb4`)
- `lib/core/services/local_connection_service.dart` — `mjpegUrl` field on `LocalConnectionData`; `_resolveMjpegUrl()` probe; resolves on connect.
- `lib/presentation/widgets/video/smart_video_view.dart` — reads `localConnectionProvider.mjpegUrl`; default const now `/video/feed`; WebRTC timeout 10s→6s; import added.
- `android/app/src/main/res/xml/network_security_config.xml` (NEW) + `AndroidManifest.xml` (ref).
- `ios/Runner/Info.plist` — ATS local-networking + usage description.
- `.claude/ROBOT_ISSUES_2026-05-31.md` (NEW), `pubspec.yaml` → 115.

### Gotchas (recurring)
- Several Edits failed on assumed surrounding text (smart_video_view MJPEG block, iOS `UIBackgroundModes` was `audio` not `voip`, pubspec bare `version:` line). Pattern this session + last: ALWAYS Read the exact lines before Edit; don't trust memory/agent line numbers. All fixed against real content.
- Bash tool relay had intermittent empty-output hiccups; used temp-file + Read workaround to confirm push (local==remote `7329fb4`).

### Unresolved / next session
1. **R-AP-1 robot-side is the blocker** — until the Pi stops tearing down its own AP, local-AP video/commands can't be validated. Hand `ROBOT_ISSUES_2026-05-31.md` to the Pi Claude.
2. **Verify Build 115 video** ONCE R-AP-1 lands: AP stays up with phone connected → confirm `/video/feed` MJPEG renders, no cleartext block.
3. **Codemagic** Builds 114+115 pushed; manual trigger is user's call.
4. **Carry-overs:** Build 114 store-and-forward still untested E2E; password-reset E2E (Build 107) untested; motor controls reportedly dead since Build 56/57, never investigated; per-robot servo calibration deferred.

---

## Session: 2026-05-30 — Build 114 (store-and-forward event replay — app side of relay buffer)
**Goal:** SG events logged on the robot while the app was offline were lost — the relay forwarded device→app events live and dropped them when no app was connected for that device_id. SG ran all morning with the app closed → hours of bark/activity events went nowhere. Build the app-side half of a per-device replay buffer (relay side built in parallel by the Lightsail Claude).
**Status:** ✅ Complete. Committed `db7b616` AND pushed to `origin/main`. pubspec at `1.0.0+114`. All touched Dart files analyzer-clean. NOT yet tested end-to-end against the live relay.

### The problem & the split
Robot is fine (sends every event, logs locally). The relay had no durable buffer for offline apps. The app already pulls 7-day history via REST `GET /api/activity` on auth transitions, but real-time WS events were in-memory only and lost if the app wasn't connected. Fix = relay keeps a per-device replay buffer + the app does a watermark handshake on (re)connect. Cross-repo contract nailed BEFORE coding (per the cross-repo coordination pattern) — relay landed as commit `a597e91`.

### Contract (final, both sides confirmed)
- **A — `last_seen_seq` on `session_hello`:** the app's connect/identify frame (relay's "user_connected path"). Relay reads it off the hello frame; missing/0 → full replay. One device_id per hello → replay is naturally per-device.
- **B — seq survives relay restart:** seq persisted to SQLite (`replay_seq`), seeded at **`persisted + 10`** on startup so the resumed counter always exceeds anything an app already saw (closes the unclean-restart reuse window I flagged). Buffered events themselves are in-memory (lost on restart) but the app then just sees an empty replay, never dupes.
- **C — shared dedup id:** stable UUID assigned once at ingest. Emitted **top-level `id` on replay frames** but **`event_id` on live-forwarded messages**; `/api/activity` reuses the same UUID for its DB row. App reads **either key** so live/buffered/REST copies of one event share an id.
- **Envelope:** `seq`, `ts_server`, `buffered`, `id`/`event_id` are top-level siblings of `type`/`event`/`device_id`.

### App-side changes (commit `db7b616`)
- **`lib/core/network/websocket_client.dart`** (the engine):
  - `WsEvent` surfaces top-level `seq`, `tsServer`, `buffered`, `id` (`id ?? event_id`) — previously discarded by the nested-`data` branch of `fromJson`.
  - `session_hello` carries `last_seen_seq` (per-device watermark), loaded from SharedPreferences in `connect()` before the frame fires.
  - `_onMessage` dedups by seq (drops `<= watermark`, collapsing overlapping replays across reconnects) and advances + persists the watermark (debounced 1s, flushed on disconnect, cancelled on dispose). Keyed per device_id. Local mode clears it (no relay buffer).
  - Bark normalization preserves seq/buffered/id and uses **server time for buffered** barks instead of stamping "now".
- **`lib/domain/providers/notifications_provider.dart`** (main activity feed):
  - Each WS-built notification uses `ts_server` for timestamp (`_resolveTimestamp`: ts_server → payload ts → now) and the relay's stable id (→ ephemeral fallback) instead of `DateTime.now()` for both. Threaded `eventTime`/`eventId` through `_createBehaviorNotification` too.
  - `addNotification` now **idempotent by id** — collapses the REST 7-day hydrate vs WS 24h replay overlap on launch into one entry.
- **`lib/domain/providers/guardian_events_provider.dart`** (SG events widget):
  - Now **subscribes across the connection lifecycle** (was screen-open only, via `event_feed.dart`) by listening to `connectionProvider` in the constructor — so replays arriving on reconnect are captured before the user opens the screen. (Discovered the screen-only subscription would otherwise miss the broadcast replay burst.)
  - Buffered events **bypass the SG-mode gate** (`if (!wsEvent.buffered && currentMode != silentGuardian) return;`) and use server time/id (injected into the data map passed to `GuardianEvent.fromJson`).
- **`.claude/STORE_AND_FORWARD_CONTRACT.md`** (NEW) — cross-repo contract note, marked RESOLVED.
- **`pubspec.yaml`** → `1.0.0+114`.

### Gotchas hit this session
- The Explore agent's line numbers for the providers were wrong/hallucinated (claimed a `_wsEventToNotification`/`_mapWsEventType` structure that doesn't exist). First batch of provider edits failed against phantom code — re-did them against the real inline-switch `_handleWsEvent`. Lesson: trust direct reads over agent line numbers for editing.
- Two pubspec version-bump edits failed (assumed strings that didn't exist; never Read the file first). Real line is a bare `version: 1.0.0+112`. Fixed + amended.

### Unresolved / next session
1. **END-TO-END TEST (only unverified link):** SG running with app closed for a while → reopen → confirm backlog appears **once** (no dupes), at the **right times**, in both the main activity feed and the SG events widget. Logic compiles + is analyzer-clean but has not run against the live relay.
2. **Codemagic** — Build 114 pushed; trigger is user's call (manual).
3. **seq reuse hardening (relay, low priority):** `persisted + 10` closes the common case; only matters if >10 events arrive in the unclean-restart window before the next persist.
4. **Carry-over (still open):** password-reset end-to-end never verified (Build 107); motor controls reportedly not working since Build 56/57, never investigated; per-robot servo calibration deferred.
5. Two stray untracked files predating this session: `archive/fits1024x1024.jpg`, `archive/treatbot2.log` (not touched).

---

## Session: 2026-05-29 — Builds 107–110 (password recovery, servo clamps, ArUco full set, device/UX cleanup)
**Goal:** Multi-topic working session. Started as password-recovery feature, expanded into servo-clamp removal, an ArUco bundle bug I'd introduced in Build 106, and a pre-ship cleanup pass (device-menu merge, dead buttons, debug prints). Plus cross-repo coordination on the relay DB-lock fix.
**Status:** All four builds committed AND pushed to `origin/main` (https://github.com/lolygagv2/dogbot-app). pubspec at `1.0.0+110`.

### Build 107 — Password recovery via emailed 6-digit code (commit `b01dd6d`)
Client side of the AWS SES-backed reset flow. A sibling Claude Code instance on the Lightsail relay built the backend in parallel; user relayed messages between us. Both ends independently proposed the same contract → zero rework.
- **Contract:** `POST /api/auth/request-reset {email}` → 200 always (no enumeration leak). `POST /api/auth/reset-password {email, code, new_password}` → `{token, expires_in}` (= login TokenResponse). 6-digit code, 15-min TTL, new code invalidates old. New password min **8 chars** (register still 6 — user said keep as-is, intentional asymmetry).
- **Files:** `auth_api.dart` (requestPasswordReset, resetPassword), `auth_provider.dart` (matching AuthNotifier methods; reset mirrors login() success path — _saveAuth, reloadForCurrentUser, _hydrateAllFromRelay), `forgot_password_screen.dart` (NEW, two-stage email→code+password via _Stage enum), `app.dart` (/forgot-password route + added to _publicPaths), `login_screen.dart` ("Forgot password?" link, sign-in mode only).
- Reset success auto-logs-in → /home. 400→"Invalid or expired code", 429→"Too many attempts".

### Build 108 — Remove app-side servo clamps (commit `6e86549`)
User: gimbal clamps (±90 pan / ±45 tilt) are "out of alignment with real physics" and every robot's gimbal + mounting is different. Removed all three `.clamp()` sites in `control_provider.dart` (setPosition, adjustPan, adjustTilt). Robot is now sole authority on its physical servo range; out-of-range gets clamped robot-side. `AppConstants.maxPanAngle/maxTiltAngle` constants KEPT — still used by the analog joystick widget (`pan_tilt_control.dart`) as deflection→degrees scale factors. Those ALSO need per-robot calibration but that's a deeper per-device-profile change, deferred.

### Build 109 — Bundle full ArUco 0–999 marker set (commit `c9c873b`)
**My own Build 106 bug.** In 106 I ran `generate_aruco_markers.py --count 50`, bundling only IDs 0–49. User's dogs use 3-digit collar markers (100–999, which the camera tracks natively) → those showed the "Marker bundle not generated" placeholder, couldn't preview/print, couldn't recreate dogs. Regenerated full DICT_4X4_1000 set (1000 PNGs, ~4 MB) via `/tmp/aruco-venv2` (opencv-contrib-python). NO code change needed — input field, save path, preview already accepted 0–999; only the assets were missing. 950 new PNGs committed; pubspec comment updated to "IDs 0–999".

### Build 110 — Device-menu merge + dead buttons + select UX + debug prints (commit `1ffeed2`)
Pre-ship cleanup. Net −148 lines.
- **Device-menu merge (user: "confusing as fuck"):** Settings had an inline `_InlineDeviceList` ("Manage Devices") AND a standalone `/device-pairing` screen that BOTH listed+selected devices → users saw their robot twice. Now: Settings shows ONE `_ManageDevicesTile` (active robot + paired count) → opens the unified `/device-pairing` screen, retitled **"My Robots"**, which owns list/select/pair/unpair. Deleted `_InlineDeviceList` AND dead `_SimpleConnectionTile`. Removed now-unused shared_preferences import.
- **3 dead buttons in `dog_profile_screen.dart`** (all were empty `// TODO`): photo avatar → opens edit screen (which owns image_picker); "See all" → Activity›Events tab (activityTabIndexProvider=1); "Goals" quick-action REMOVED (no destination existed).
- **Faster select UX:** selecting a robot shows "Connecting to <name>…" snackbar + `context.go('/home')` so user watches it connect instead of sitting on the list. Badge already moves Waiting…→Robot Online; list shows ACTIVE instantly. (Snackbar survives the go() because MaterialApp.router hosts a root ScaffoldMessenger.)
- **Debug prints:** gated the per-message WS firehose (`WS MSG`/`WS SEND`) in `websocket_client.dart` behind `kDebugMode` (added `flutter/foundation` import). Other low-volume state prints left as-is.

### Pre-ship audit (Explore agent) — corrected two false positives
Ran a broad audit agent. Real find: the 3 dead buttons (fixed). **Downgraded:** `auth_api.dart:105` "silent catch" is the INTENTIONAL tri-state (`return TokenValidation.unreachable`) — not a bug. WS prints were NOT a "CRITICAL security leak" (no tokens in payloads) — just noise, now gated.

### Relay DB-lock fix (cross-repo, Lightsail Claude — VERIFIED)
Root cause of BOTH the password-reset failures AND slow/stuck video connect: relay's raw sqlite3 was `journal_mode=delete` + `busy_timeout=0` → a robot-status write colliding with a reset-code insert failed instantly with SQLITE_BUSY → 500. My SES-in-transaction guess was WRONG (SES was already post-commit). Lightsail Claude fixed: `journal_mode=WAL` + `busy_timeout=5000` on every connection, + wrapped all 52 DB functions in a `with db_connection()` context manager (leak protection). Verified: service restarted, WAL sidecars (`-wal`/`-shm`) confirmed created with correct dir perms. App-side confirmed: Dio timeouts (10s connect / 30s receive, `app_constants.dart:6-7`) comfortably exceed the 5s busy_timeout, so the retry window is fully usable — NO app change needed.

### Unresolved / next session
1. **END-TO-END TEST password reset in the app** — only unverified link. Tap "Forgot password?", confirm SES email arrives + reset completes. (Earlier failure today was the DB locks, now fixed.)
2. **Codemagic** — Builds 107–110 pushed; trigger is user's call (manual).
3. **Per-robot servo calibration** — analog joystick (`pan_tilt_control.dart`) still scales by the old ±90/±45 constants. Needs a per-device calibration profile (range + mount orientation). Robot-side ticket territory.
4. **Carry-over:** motor controls reportedly not working (user-reported since Build 56/57), never investigated.
5. WAL checkpoint-on-close under bursty traffic is an optimization knob (`wal_autocheckpoint`/`synchronous=NORMAL`) — only touch if latency spikes appear under load. Not pre-ship.

---

## Session: 2026-05-28 — Build 106 (6-item user-complaint triage + ArUco bundle + robot brief)
**Goal:** User came in with six complaints from Build 104/105 testing — ArUco UX, generic "dog" name in coach mode, coach trick TTS skipping, bark spam, device online/offline disagreement, unpair 500. Diagnose each, fix what's app-side, write a robot brief for the rest.
**Status:** Completed — single commit `6d32a52` (`feat: 6-item triage sweep + ArUco bundle + robot brief — Build 106`) on main, pubspec at `1.0.0+106`. Untriggered Codemagic — user's call.

### Triage outcome (six complaints → three app-side fixes + three robot tickets)

| # | Complaint | Where it lives | Action |
|---|-----------|----------------|--------|
| 1 | ArUco markers route user to chev.me — print flow felt "meh" | Setup never ran `scripts/generate_aruco_markers.py`; pubspec assets line was commented since the script was written | **App-side fix** — generated first 50 markers (204 KB), uncommented pubspec. Embeds direct PNG now for IDs 0–49; chev.me fallback only fires for IDs ≥50 |
| 2 | Coach mode calls dog by generic "Dog" instead of profile name | `force_trick` payload was bare `{trick}` — no identity carried | **App-side fix** — see "Fix #2" below |
| 3 | "Sit" audio doesn't play at trick start, inconsistent prompt audio | App only sends `force_trick` over WS; no local audio. Robot is supposed to TTS but skips it | **Robot ticket R3** — app cannot fix, robot's coach engine must reliably TTS before wait window starts. Offered as future option: local audio fallback in app (assets/audio/{sit,stay,…}.mp3 via audioplayers, already in pubspec) — punted until R3 ships and is confirmed insufficient |
| 4 | Bark events still flooding feed | Already documented as robot-side R2 in `.claude/ROBOT_ISSUES_2026-05-27.md`. App-side already routes to in-app-only by default | **Robot ticket R2** (carryover) |
| 5 | Manage Devices shows "offline" while video is actively streaming; "Add Device" shows same paired device, confusing | (a) REST `is_online` lagging behind WS-truth during initial render; (b) Add Device intentionally lists paired devices — UX confusion, not a bug | **App-side fix (5a)** — see "Fix #5a" below. **Deferred (5b)** — rename Add Device flow / split screen, needs UX call from user |
| 6 | Unpair returns Error 500; works after app restart | Either (a) stale JWT at `device_api_provider` construction, or (b) relay returns 500 for orphan pairings instead of 404. Pre-existing 404→`dismissLocally()` recovery path didn't catch 500 | **App-side fix** — treat 500 same as 404 (belt-and-suspenders). Robot ticket **R5** to return proper status codes |

### Fix #2 — `force_trick` carries dog identity
**Problem:** `coach_provider.forceTrick(String trick)` sent only `{trick: 'sit'}`. Robot's TTS template substituted "Dog" because there was no `dog_name` in the payload, even when the user had a profile selected and/or an ArUco-detected dog visible. The comment at `coach_screen.dart:210` already said "Do NOT use selectedDog.name for display — that locks to profile selection," but commands need *intent*, not just camera ground truth.

**Solution:** Resolve identity in priority order inside the notifier:
1. Detected (ArUco via `coachState.dogId`/`dogName`)
2. Selected profile (`selectedDogProvider.id`/`name`) — fallback when nothing detected yet
3. Neither → return `false`, caller shows snackbar

Concrete edits:
- `coach_provider.dart`: added `dogId` field to `CoachState`; updated `copyWith`; capture `dog_id` in three event handlers (`detection`, `coach_reward`, `coaching_started`); `forceTrick` returns `bool`, resolves identity, refuses with `false` if no dog known.
- `websocket_client.dart`: `sendForceTrick(String trick, {String? dogId, String? dogName})` — only adds fields to payload when non-null, so robot can still fall back to its previous behaviour if a future caller skips them.
- `coach_screen.dart` + `drive_screen.dart`: both had trick chips wired to `forceTrick(behavior)`. Both now wrap the call — show "Select a dog or wait for the camera to identify one." snackbar when `forceTrick` returns false.

### Fix #5a — Active device forced "online" in Manage Devices
**Problem:** REST `device.isOnline` lags after WS connect. Build 104's merge logic at `paired_devices_provider.dart:142-145` already trusts WS over REST (`putIfAbsent` for REST), but if the relay hasn't pushed a `device_status` event yet for the active device, the map is empty and REST's stale `false` seeds it. Result: "offline" badge while user is literally streaming video from the device.

**Solution:** After the merge, if `deviceIdProvider != null` and `connectionProvider.status == ConnectionStatus.robotOnline`, force-set that device id to `true` in `mergedStatus`. We KNOW it's online — we're talking to it. Demo mode is excluded (status check is direct enum compare, not `isRobotOnline` getter which includes demo).

Added `import 'connection_provider.dart'` to `paired_devices_provider.dart`.

### Fix #6 — Unpair 500 → local-dismiss recovery
**Problem:** User reports Error 500 on first unpair attempt, succeeds after cold restart. Two candidate root causes — stale auth token (provider built once at app start) or relay 500'ing instead of 404'ing for orphan pairings. Either way the user was stuck.

**Solution:** One-line change in `paired_devices_provider.unpairDevice` — `if (code == 404 || code == 500)` returns `UnpairOutcome.orphaned`. The existing Build 94 recovery (`dismissLocally()` hides the device locally so the pairing row stays orphaned server-side but the UI unblocks) now catches 500 too. True root cause still needs robot/relay fix (logged as R5).

### ArUco bundle
- Spun up `/tmp/aruco-venv` (system Python 3.12 blocked PEP 668 install). `pip install opencv-contrib-python` → ran `scripts/generate_aruco_markers.py --count 50`.
- Output: `assets/markers/aruco_4x4_1000/{0..49}.png`, 204 KB total, ~3 KB each.
- Uncommented pubspec assets line; tagged with `# DICT_4X4_1000 markers (IDs 0–49 bundled, Build 106)`.
- `_printMarker` in `edit_dog_screen.dart:480` already had embed-vs-chev.me branching (Build 104). With markers bundled, the common case (IDs 0–49) hits the embed branch. chev.me fallback only triggers if a user manually enters ID ≥50 — acceptable corner case.

### Robot brief — `.claude/ROBOT_ISSUES_2026-05-28.md`
New file (NOT to be confused with `.claude/ROBOT_ISSUES_2026-05-27.md`). Covers:
- **R3** — Coach trick TTS skipping. Suggests synchronous speak-then-unblock + a new `coach_trick_prompted` ack event the app can use to detect failures + interlock concerns with bark-detection self-mute gate.
- **R4** — `force_trick` payload now carries `dog_name`. Robot must substitute it into TTS template. Also addresses autonomous coach rewards (no `force_trick`) — should still skip name rather than say "Dog" if `select_dog` state is empty.
- **R5** — Unpair 500. Includes orphan-pairing handling guidance, JWT/race candidates, request format the app currently sends, and the app's `{200, 404, 500} = unblocked` Build 106 contract.
- Carries forward **R1** (spin classifier false positive while dog ran into wall) and **R2** (bark spam) from 2026-05-27.

### Verification
- `flutter analyze` on the 5 modified Dart files: 37 issues, all pre-existing `withOpacity → withValues` infos and `prefer_const_*` style nits. **No new errors or warnings from Build 106.**
- All callers of `forceTrick` audited (`grep -rn forceTrick lib/`) — two callsites (coach_screen + drive_screen), both updated to handle the new `bool` return + snackbar.

### Files modified (6) + new files (2)
**Modified:**
- `lib/core/network/websocket_client.dart` — `sendForceTrick` signature
- `lib/domain/providers/coach_provider.dart` — `CoachState.dogId`, 3 event handlers, `forceTrick → bool`
- `lib/domain/providers/paired_devices_provider.dart` — connection_provider import, active-device force-online, 500→orphan
- `lib/presentation/screens/coach/coach_screen.dart` — snackbar fallback
- `lib/presentation/screens/drive/drive_screen.dart` — snackbar fallback (same logic)
- `pubspec.yaml` — version 1.0.0+105 → +106, uncommented assets/markers line

**New:**
- `.claude/ROBOT_ISSUES_2026-05-28.md` — robot-team brief
- `assets/markers/aruco_4x4_1000/{0..49}.png` — 50 ArUco PNGs

### Open items / next steps
- **Trigger Codemagic for Build 106** — user's next action. Single bundled build covers all three app-side fixes + ArUco assets.
- **Hand off robot brief** — R3, R4, R5. R1 + R2 still pending from 2026-05-27.
- **Issue #5b deferred** — "Add Device shows already-paired devices" is a UX call. Options: rename to "Pair / Manage Devices", split into separate screens, or leave with better section labels. Awaiting user direction.
- **R3 follow-on** — if robot-side TTS fix lands and audio is still flaky, fall back to local audio assets (audioplayers is already in pubspec; would need `assets/audio/{sit,stay,laydown,come,spin,speak}.mp3` recorded and bundled).
- Carried from prior sessions (still open): relay-side ticket for blind `(user_id, device_id)` unpair (now interlocks with R5 — same recovery code path).

### Important notes / warnings
- **`forceTrick` is now `bool`-returning.** Any future caller must handle the false case (currently: coach_screen + drive_screen both snackbar). If a third caller is added without the check, "no dog identified" will silently swallow the tap.
- **The `force_trick` payload now includes optional `dog_id`/`dog_name`.** Robot must be backward-compatible — `data['dog_name']` may be missing on older app builds, and `force_trick` from non-app sources (CLI tests?) may also lack it. Robot should not assume presence.
- **Active-device force-online (#5a) is a one-shot during `loadDevices()`.** If the user disconnects while looking at Manage Devices, the map won't auto-revert to "offline" for that device until the next `device_status` WS event lands. Acceptable — disconnect path is rare and the WS event normally fires.
- **The 500→orphan recovery (#6) masks real server errors.** If the relay starts 500'ing for a *new* reason (not orphan, not stale JWT), users will silently see the device disappear from their list. R5 must be solved properly server-side; this is a mitigation, not a fix.
- **Protected files:** `notes.txt` and `/docs/` are still MISSING — flagged at session start. Not touched by this session.

---

## Session: 2026-05-25 (cont.) — Build 100 (Video-Lag Fix + Night-Mode Wire-Format Fix)
**Goal:** User reported back during the same day with two remaining issues: (1) night-mode toggle "not exactly easy updating" — i.e. the UI was wired but commands weren't reaching the robot, and (2) the long-standing "1–5 second black screen when you tab away from /home and come back" lag was *still* present after Build 99. Robot side now accepts a new contract for night-mode override; need to align app side.
**Status:** Completed — single commit `ed6e472` pushed to main, pubspec bumped to `1.0.0+100`. User said to bump, commit, push — done. Codemagic untriggered (their call).

### Issue 1 — Night-mode commands silently dropped (websocket_client.dart:1081)
Robot just got a working night-mode controller with both relay + HTTP endpoints. Wire contract (from `/home/morgan/dogbot/services/cloud/relay_client.py` per the user's brief): override commands MUST ride the standard relay-command envelope (`{type:command, command:set_night_mode_override, device_id, data:{override}, timestamp}`), same wrapper as `set_mode` and `mood_led`. Old `sendNightModeOverride()` emitted a *bare* typed frame `{type:set_night_mode_override, override}` — relay had no `_handle_command` path for that, so frames were dropped without ack. **Fix:** routed through `sendCommand('set_night_mode_override', {'override': override})` — one-line change, picks up `_targetDeviceId` + timestamp automatically. No other call sites needed updating; the optimistic local-state update in `night_mode_provider.setOverride()` is unchanged.

### Issue 2 — `last_changed_at` parse silently nulled (night_mode_state.dart:94)
Spec from this session's brief explicitly: `last_changed_at: 1779689015.24` (Unix epoch *float*, not ISO). Old `fromJson` was `if (ts is String) DateTime.tryParse(ts)` — robot never sends a string, so the field was always null and the "Last changed" line in the Settings panel was always blank. **Fix:** accept `num` (multiply by 1000 → `fromMillisecondsSinceEpoch`) with the ISO string path kept as a fallback. No call sites touched. Found via re-reading the brief; bug was latent from the moment the model was first added in Build 99.

### Issue 3 — Tab-switch video lag (app.dart, ~150-line refactor)
Root cause finally pinned: `ShellRoute` in GoRouter disposes the active branch's widget tree whenever the user switches branches. `HomeScreen` (which owns the `SmartVideoView` → `WebRTCVideoView` → `RTCVideoView`) was being **destroyed** on every nav to /missions or /settings. The Riverpod-held `RTCVideoRenderer` + peer connection + `MediaStream` all survived in the provider (`webrtcProvider`), so `requestVideoStream()` correctly skipped re-negotiation on return — but the iOS native `RTCVideoView` platform-view is a *fresh widget instance* on remount and has to re-bind its native texture to the surviving renderer. That binding handshake is what cost 1–5s of black. Provider-level fixes would never have caught this because the provider was never the problem.

**Fix:** migrated the shell from `ShellRoute(builder, routes)` → `StatefulShellRoute.indexedStack(builder, branches)`. All 6 tabs (home, dogs, missions, gallery, activity, settings) become `StatefulShellBranch` entries; `MainShell` signature swapped from `Widget child` to `StatefulNavigationShell navigationShell`, which IS an IndexedStack under the hood. Tabs stay mounted across navigation; only visibility toggles. Bottom-nav onTaps now call `navigationShell.goBranch(index, initialLocation: index == currentIndex)` instead of `context.go(path)` (the conditional `initialLocation` preserves the previous "tap selected tab to pop nested stack" behavior). Removed dead `_getTabIndex(location)` helper. `_shellNavigatorKey` no longer used (each branch owns its own navigator key now).

**Programs/missions merge:** the old shell had `/missions` and `/programs` as sibling routes pointing to the same `MissionsScreen`. Since `StatefulShellBranch` needs every tab's routes co-located, I put both under the missions branch — `/programs` and `/programs/:id` live alongside `/missions` and `/missions/:id` in branch 2. Both nav paths still reach the same screen; bottom-nav still highlights "Missions" because branch index is now owned by the shell (no more path-prefix parsing).

**Top-level routes unchanged:** `/login`, `/`, `/demo`, `/drive`, `/coach`, `/history`, `/scheduler`, `/device-pairing`, `/voice-setup`, `/dog/:id` stay outside the shell, so they still cover the bottom nav when pushed (correct behavior).

**Bonus side-effects:** Missions list no longer re-fetches on every tab return; Settings keeps its scroll position; Activity badge state survives tab switches. Memory cost is negligible — none of the offstage screens hold heavy state, and the only stream subscriptions are Riverpod-managed (already efficient under offstage rebuilds).

### Verification
- `flutter analyze lib/` — 403 issues, all pre-existing (`withOpacity → withValues` deprecation infos + scattered unused-import warnings). No new errors or warnings from this session's edits. Same surface as Build 99.
- `flutter analyze` per-file on the 4 changed files (`app.dart`, `websocket_client.dart`, `night_mode_state.dart`, `pubspec.yaml`) — only `prefer_const_constructors` info-lints on `app.dart`, no errors.
- Single `MainShell(` call site in `app.dart` itself — refactor signature change cleanly contained.

### Files modified (4 — no new files this session)
- `lib/app.dart` — ShellRoute → StatefulShellRoute refactor; `MainShell` signature; bottom-nav goBranch
- `lib/core/network/websocket_client.dart` — `sendNightModeOverride` switched to relay-command envelope
- `lib/data/models/night_mode_state.dart` — `last_changed_at` accepts numeric Unix epoch
- `pubspec.yaml` — bumped `1.0.0+99` → `1.0.0+100`

### Open items / next steps
- **Trigger Codemagic for Build 100** — user's next action; this build should resolve both the night-mode controllability + the long-standing tab-switch lag in one shot.
- **WebRTC handshake bug** still deferred from prior session — needs iOS Console.app logs from a TestFlight repro to make any further app-side change worth a paid build. If Build 100's tab-switch fix happens to make the handshake bug visible/easier-to-trigger, capture logs then.
- **Robot-side night vision** — still a separate ticket per `.claude/nightvision.md`. Build 100 now correctly *talks* to the robot using the documented envelope, but robot must implement the controller side. User's brief in this session quotes the relay+HTTP handler signatures, suggesting the robot side is either done or in progress (the relay reference paths in `/home/morgan/dogbot/services/cloud/relay_client.py` and `/home/morgan/dogbot/modes/night_mode_controller.py` were cited as ground truth — those are on the robot repo, not this one).
- Carried from prior sessions (still open): `scripts/generate_aruco_markers.py` + uncomment the assets line in pubspec; relay-side ticket for blind `(user_id, device_id)` unpair.

### Important Notes/Warnings
- **Why the lag fix had to be at the routing layer**, not the WebRTC provider: the provider was working correctly the whole time. Past investigations (Build 44's "always close on switching device") added defensive close+retry logic in `requestVideoStream` precisely because the lag *looked* like a provider issue. It wasn't — the provider was repeatedly skipping renegotiation as designed. The lag was at the texture-binding layer, one step further down. Worth noting for future "video is slow to appear" reports: always check whether the host widget is being unmounted first.
- **`StatefulShellRoute` is a substantial routing refactor** — every screen that calls `context.go('/home')` or `context.push('/settings/...')` continues to work because GoRouter still resolves paths against the branch tree, but anything that subclassed `MainShell`-aware navigation logic (none found in current code, but worth checking on future PRs) would need updating to `navigationShell.goBranch`.
- **Branch memory:** each tab stays mounted indefinitely. None of the current tab screens hold heavy off-screen state (lists/forms only). If we ever add a tab that subscribes to a high-frequency stream and doesn't pause off-screen, we'd want a `Visibility`/`Offstage`-aware subscription pattern there.

### Post-build user Q&A — "Why is EXIT showing on cold-open?"
User reported the home screen's Idle button rendering as red "EXIT" right after app open and asked if it was a bug. Not a bug — `home_screen.dart:365` derives `isExitButton = mode == RobotMode.idle && displayMode != RobotMode.idle`, so the EXIT badge only appears when the robot reports a non-idle current mode. `modeStateProvider` defaults to `RobotMode.idle` but is immediately overwritten by the first inbound telemetry / `mode_changed` frame. The robot persists its last mode across power cycles, so if the user left it in Silent Guardian (or Coach) last session, on next boot the Pi resumes that mode and the app correctly mirrors it. The EXIT button itself is the *intended* one-tap escape hatch. Diagnostic path for future "is this a bug?" repeats: open Settings → Connection Diagnostics and check the first inbound `telemetry`/`mode_changed` after WS open — if `mode != idle`, robot-side persistence is the explanation; if `mode == idle` and EXIT still shows, *then* it's an app bug worth chasing in `mode_provider`. If the user later decides they want the robot to boot to Idle regardless of last state, that's a one-line robot-side change (don't restore persisted mode on startup), not an app fix.

---

## Session: 2026-05-25 — Build 99 (Night Vision + Cold-Open Fix + Multi-Robot Switch Fix)
**Goal:** Bundle night-vision UI on top of carry-over expired-session UX (Build 99 from prior session, never shipped); diagnose & fix two reported user issues before Codemagic.
**Status:** Completed — 5 commits pushed to main, tip `bc8f944`, pubspec `1.0.0+99`. User confirmed ready to trigger Codemagic.

### Inherited from prior session (was already committed as 0e63028 before this session began)
- Expired-session UX: router `refreshListenable` + protected-route guard; `_AuthInterceptor` for REST 401 → `DioClient.onUnauthorized`; `AuthState.loginNotice` survives `logout()` reset; login screen banner. Carries through.

### Part A — Night vision app-side (commit 37783f4, originally tagged "Build 100")
Robot decides day/night from NoIR + lux + 940nm IR illuminator; app reflects state and exposes Auto/Force Day/Force Night override. Spec was `.claude/nightvision.md` (now committed).
- **Wire contract:** inbound `night_mode_state` (mode/override/lux/last_changed_at, 60s heartbeat) and outbound `set_night_mode_override`. WS client's generic typed-message dispatch already forwards inbound through `eventStream` — only added outbound helper `sendNightModeOverride()`.
- **NEW** `lib/data/models/night_mode_state.dart` — `DayNight`/`NightModeOverride` enums + immutable `NightModeState` (plain Dart, matches `VideoQualityState` style) + `luxLabel()` thresholds.
- **NEW** `lib/domain/providers/night_mode_provider.dart` — `StateNotifier<NightModeState?>` subscribed to `eventStream`, optimistic `setOverride()`, 90s heartbeat-stale flag via `Timer`-driven re-emit. Sibling `nightModeIsStaleProvider`.
- **NEW** `lib/presentation/widgets/night_mode/mode_badge.dart` — display-only sun/moon badge for drive screen top-right (per user choice, override lives in settings, not on badge).
- **NEW** `lib/presentation/widgets/night_mode/night_vision_settings_section.dart` — mode header, lux + label, last-changed relative timestamp, `SegmentedButton` for Auto/Day/Night, override-active warning, stale-state notice.
- **MODIFIED** `drive_screen.dart` — embedded `ModeBadge`; added cool-tone night border via `Positioned.fill` + `IgnorePointer`; `ref.listen<NightModeState?>` triggers 4s "Switching to night/day mode…" SnackBar on transition.
- **MODIFIED** `settings_screen.dart` — new "Night Vision" section after "Camera".
- **MODIFIED** `app_theme.dart` — added `primaryNight` (steel-blue `0xFF5B8EE8`) + `darkNight` ThemeData variant that re-derives every widget theme binding the primary colour.
- **MODIFIED** `app.dart` — `MaterialApp.router` theme picks `darkNight` when `nightModeProvider.currentMode == DayNight.night` (app-wide chrome shift per user choice).
- **Pixel-purity preserved** — no `ColorFilter`/saturation/etc. applied to the video stream itself; only chrome adapts. Confirmed end-of-session via grep: zero color-manipulation primitives in `lib/`.

### Part B — Cold-open auto-connect (commit 63d7624, originally tagged "Build 101")
User-reported: cold-open with valid stored JWT lands on /home with WS never connecting; "Reconnecting…" forever; only logout+login fixes. Root cause: silent re-auth in `auth_provider._loadSavedAuth` set `isAuthenticated:true` but never called `connectionProvider.connect()` — login_screen.dart:107 does this explicitly post-login but the silent path didn't mirror it. Bug pre-dated Build 99 (likely Build 94 when silent re-auth was added) but became more visible because Build 95's tri-state validation reliably restores valid JWTs to a dead-WS state. **Fix:** read saved host/port from prefs inside `_loadSavedAuth` after successful validate and fire-and-forget `_ref.read(connectionProvider.notifier).connect(host, port)`. New import: `app_constants.dart` for the prefs keys.

### Part C — Multi-robot in-session switch (commit bc8f944)
User-reported: switching from robot A → robot B via Settings → "Manage Devices" list never loads video; only logout+login (with B selected) works. Root cause confirmed via reading `_sendSessionHello` in `websocket_client.dart:649-661`: **the relay binds each WS session to the `device_id` in `session_hello` ONCE at WS connect time**. `wsClient.setTargetDevice()` only updates the app-local inbound filter (`_isFromTargetDevice` at line 305) — it does NOT tell the relay to rebind, so every command (including `webrtc_request` for B) flows through a WS session the relay still routes to A. Logout/login worked because it produced a brand-new WS with brand-new session_hello.
**Fix:** `webrtc_provider._handleDeviceSwitch` now: tear down WebRTC → set `_lastDeviceId = newId` → `connectionProvider.notifier.reconnect()` (closes WS, reopens with new session_hello carrying current `deviceIdProvider`). Existing `deviceStatusStream` listener at line 289-308 auto-fires `requestVideoStream(_lastDeviceId!)` once the freshly-bound relay reports the new robot online. Removed the old close+wait+request inline logic. Added `import 'connection_provider.dart'`.
**Side-effect bonus:** this also closes the cold-open race where `connect()` may fire before `deviceIdProvider` finishes its async `_loadDeviceId` — the listener will now trigger a corrective reconnect when the saved id materialises.

### Part D — Spec hygiene (commit 51fcc73)
Discovered `.claude/local_notifications.md` (164-line spec) was actually already shipped: `lib/core/services/notification_service.dart` (`FlutterLocalNotificationsPlugin` singleton, iOS/Android init, `showForEvent`), `main.dart:22` init, `notifications_provider.dart:256-269` per-type routing via `settings.channelFor(type)` + `isAppBackgrounded` gate, plus `notification_preferences_screen.dart`. User confirmed they've actually been getting lock-screen pings — spec just lingered uncleaned. Moved spec to `archive/local_notifications_SPEC_SHIPPED.md` so future sessions don't re-read it as aspirational.

### Build numbering
Originally committed under sequential 99/100/101 message labels; consolidated to a single Build 99 in commit 1da423f because Codemagic was never triggered for the intermediate numbers. pubspec is currently `1.0.0+99`; the historical "Build 100/101" commit messages live in git log as harmless noise.

### Verification
- `flutter analyze lib/` — no errors introduced by this session. All 400+ findings are pre-existing `withOpacity → withValues` deprecation infos that pervade the codebase, plus pre-existing `unused_import`/`unused_element` warnings in files we didn't touch.
- `flutter analyze` per-file on every modified/new file returned `No issues found`.
- Outside `lib/`: a stray `/home/morgan/wimzapp/wimz-app-theme/` directory at the project root surfaces errors when running `flutter analyze` without an explicit `lib/` argument — pre-existing, unrelated, not in the iOS bundle. Surface in a future cleanup session if it bothers anyone.

### New files this session (4)
- `lib/data/models/night_mode_state.dart`
- `lib/domain/providers/night_mode_provider.dart`
- `lib/presentation/widgets/night_mode/mode_badge.dart`
- `lib/presentation/widgets/night_mode/night_vision_settings_section.dart`

### Modified files (8 + pubspec)
- `lib/app.dart`, `lib/core/network/dio_client.dart` (carry-over from prior session), `lib/core/network/websocket_client.dart`, `lib/domain/providers/auth_provider.dart`, `lib/domain/providers/connection_provider.dart` (carry-over), `lib/domain/providers/webrtc_provider.dart`, `lib/presentation/screens/auth/login_screen.dart` (carry-over), `lib/presentation/screens/drive/drive_screen.dart`, `lib/presentation/screens/settings/settings_screen.dart`, `lib/presentation/theme/app_theme.dart`, `pubspec.yaml`.

### Open items / next steps
- **Trigger Codemagic for Build 99** — user said they'd build immediately after session.
- **Robot-side night vision** — separate ticket. Wire contract is in `.claude/nightvision.md` (now committed). Pi-side needs: publish `night_mode_state` on transition + 60s heartbeat, accept `set_night_mode_override`, IR cut filter + 940nm illuminator + AE/gain switching.
- **Separate WebRTC handshake bug seen in user's robot logs** (offer arrives, app never sends answer, ~4-5s close, repeats). Not addressed this session because diagnosis requires iOS Console.app logs from a TestFlight binary. **Recommendation logged:** ship Build 99, capture iOS logs filtered to `WebRTC:` prefix during a failure repro, then diagnose with ground truth. Suspect the catch block at `webrtc_provider.dart:534-540` is swallowing a useful error without stack trace — adding stack-trace logging there might be the first investigative move.
- Carried from prior sessions (still open): trigger Codemagic; `scripts/generate_aruco_markers.py` + uncomment the assets line; relay-side ticket for blind `(user_id, device_id)` unpair.

### Important Notes/Warnings
- Build cost concern: user explicitly flagged that each Codemagic build costs money. Do not propose a second build without ground-truth data (e.g., iOS Console logs) that makes the next fix high-confidence.
- The night-vision app-side ships ahead of the robot side intentionally — until robot starts publishing `night_mode_state`, badge is silently hidden and settings panel shows "Waiting for robot…". Both are intended fallbacks.
- "Local notifications" lesson: feature was already implemented but the spec doc was never removed. User remarked "sometimes i've skipped session notes" — future sessions should sanity-check `.claude/*.md` spec docs against `lib/` before assuming they're aspirational.

---

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
