# WIM-Z Development TODO List
*Last Updated: June 2026 · Build 106*

## Current Status: Build 106 — Fleet Reliability Hardening

**Build Phase:** CORE COMPLETE — hardening + manufacturing prep
**Fleet:** 5 units (treatbot1–5) built & operational, one codebase + per-unit profiles
**Current Focus:** Reliability (power/freeze, timing), cloud-history correctness, per-unit calibration, validation of scheduler + summaries

---

## 🔥 CURRENT OPEN ITEMS (June 2026)

### OTA robot software updates — app-triggered, safe rollback (added 2026-08-07, DESIGN phase)
- [x] Contract draft written: `.claude/OTA_UPDATE_CONTRACT_2026-08-07.md` — app/relay/robot slices, bootstrap plan, acceptance tests
- [x] **App slice SHIPPED Build 154 (2026-08-30):** Settings "Robot Software" card (version vs latest, UPDATE + confirm dialog, update_status progress, terminal states), sw_version telemetry parse, getLatestRelease (404-tolerant), update_status WS routing + transient watermark carve-out, start_update command — inert until relay/robot ship
- [x] **Robot slice IMPLEMENTED (robot c28ed1f, 2026-08-31):** event shape confirmed as-is; data layout `/home/morgan/wimz/releases/<v>` + `wimz/shared/`; service treatbot.service; sw_version ships pre-freeze (tb5 = 2026.08.1); terminal events up to ~90s after restarting (encoded app-side B155). Bootstrapping tb5 now, then tb1–tb4
- [x] **Relay slice SHIPPED (confirmed 2026-09-01):** first live end-to-end OTA on tb5 — 48s tap-to-healthy. FEATURE COMPLETE.
- [x] Fleet adoption: ALL ACTIVE robots on OTA (tb3/China assumed permanently offline until further notice)

### SG bark analytics + Panic + Loop (robot 137a5e8, 2026-08-31) — app slice SHIPPED B155
- [x] App slice B155: sg_summary card + level4 notification, panic_alert notifications, guardian-stopped wrap-up entry, Loop button, sg_status_pull/audio_loop commands, watermark carve-out for status_pull replies (brief: `.claude/ROBOT_BRIEF_SG_PANIC_LOOP_2026-08-31.md`)
- [x] **Panic push resolved (2026-09-01):** relay reuses the EXISTING generic push pipeline (same one as "Treat dispensed") with the PANIC text — no new FCM event-type mapping needed. Note: app's panicAlert/sgSummary per-type notification prefs won't gate a generic-typed push; acceptable for v1.
- [ ] Live test: SG summary pull, panic push end-to-end, Loop button echo; verify sg_status_pull/audio_loop work over /ws/local (REST fallback GET /sg/summary + POST /audio/loop not wired app-side)
- [x] **SG phantom treat RESOLVED 2026-09-01:** treat mid-barking traced to a leftover "Bark reward" path (random treats for novel barks, Coach "Speak" scaffolding) running alongside SG — robot REMOVING it (`.claude/ROBOT_BUG_SG_PHANTOM_QUIET_2026-09-01.md`). Retest SG post-removal on app B157; still open: confirm SG's real reward path announces praise before dispensing
- [x] **Chart SHIPPED Build 157 (2026-09-01):** bark_timeline stacked-bar chart (per-bucket, typed colors matching the card legend, baseline-anchored, start/end time axis) + trend_detail rate line ("now X/min · session Y/min") in SgSummaryCard; parsed into SgSummary (SgTimelineBucket/SgTrendDetail)

### Real push notifications (FCM/APNs) — ✅ DONE (confirmed live 2026-08-30)
- [x] **App slice SHIPPED 2026-07-30:** firebase_core/messaging deps, PushService, pushSyncProvider (register on login, re-sync on prefs/token change, unregister on logout), /api/push endpoints in RobotApi, iOS aps-environment entitlement; activated with real firebase_options.dart (`wimzpushy`)
- [x] **Relay slice:** implemented relay commit 409f381 per `.claude/PUSH_NOTIFICATIONS_CONTRACT_2026-07-30.md` + deployed (see `.claude/APP_BRIEF_FROM_RELAY_2026-07-30_push_slice.md`)
- [x] **Morgan setup:** Firebase project + `flutterfire configure` + APNs/console steps completed
- [x] End-to-end: Morgan confirmed 2026-08-30 — lock-screen banners arrive with app closed

### Reliability / Safety (highest priority)
- [ ] **Silent hard-freeze RCA** — recurring lockups with no kernel/software trace (corrupt journal). Power-rail evidence collector deployed on treatbot2; awaiting next occurrence to rule brownout vs true hang.
- [x] **Power-button SPOF — SOLVED (2026-09-01):** every robot now has a hardware-direct OFF switch; quick physical kill for any circuit problem.
- [x] **RTC batteries installed (2026-09-01):** all Pi clocks battery-backed; cross-boot timestamps trustworthy.
- [x] **treatbot2 dispenser — FIXED:** fault was a bad crimp on a stepper coil wire (not the TMC2209 chip); repaired.
- [x] **B147 drive-screen visual regression check** — completed and passed.

### Validation (blocking "done" claims)
- [ ] **Mission Scheduler** — validate auto-start, time-window enforcement, once/daily/weekly logic (implemented, never tested)
- [ ] **Weekly Summary** accuracy — verify before it becomes an owner/investor metric
- [ ] End-to-end cloud history after service restart — SG run → bark/guardian/treat all appear in app history (fixes committed 3250698 / f18adb2, dormant until restart)

### Silent Guardian design decisions
- [x] **Post-cap behavior — DECIDED 2026-09-01 (Morgan): accept as-is.** 11-treat cap + 600s eligibility cooldown = cap reachable after ~110 min of continuous compliance; risk (learned irrelevance / extinction burst) only materializes if sessions actually hit the cap. Revisit ONLY if real sg_summary data shows the tell: treats flatlined at 11 + interventions climbing + trend "worsening" in the session's back half. Fix then = expose cap in profile yaml.
- [ ] Expose `treat_eligibility_cooldown` (hardcoded 600s in `silent_guardian.py:132`) to profile yaml — still open, low priority
- [x] **Robot confirms received (7aa9231):** 11-treat cap = raw constant (session_limits.max_treats yaml); SG stop/restart resets BOTH treat budget and 600s cooldown — all-day-dog restart workaround fully validated. Telemetry 30d fleet-wide implemented. /ws/local pull commands (sg_status_pull, audio_loop, dog_weekly_summary_pull) were missing, now wired + live-verified robot-side; app parser confirmed compatible (B146 unwrap), no app change needed

### Data / ML
- [x] **Per-dog weekly summary — app slice SHIPPED Build 158 (2026-09-01):** robot 386aef0 live on tb5; dog_weekly_summary_pull → Weekly Summary card on dog profile (auto-pull on open, headline verbatim, bark-type bar, treats/quiets/coaching/guardian). Full-type watermark carve-out. Verify on device; confirm /ws/local handles the command
- [x] **BACKFILL DONE (robot c032823, 2026-09-01):** legacy DBs retrofitted into wimz.db per Amendment A with all 4 app flags honored — origin provenance (spec v0.7), normalized epoch-ms UTC, NULL-never-guess ladder, 5 bark-lottery rows tagged+excluded, storage-only (no re-emission/pushes). Recovered: 1,176 rewards, 91 coaching, 11 SG sessions + 203 interventions, 2,160 pose events; STORE-A rescued household bark rows to early July. Per-dog bark rows honestly start 2026-09-01. **App B159:** coverage caption rendered on Weekly Summary card ("Data since: treats Jul 22 · …"); change_percent null → '—' already handled
- [ ] **Data refactor** — GREEN-LIT by Morgan 2026-09-01; robot already on Phase 2 (spec bump v0.6). App review APPROVED with notes (`.claude/APP_REVIEW_DATA_REFACTOR_2026-09-01.md`) — followed_by as export query (join window must land in spec), ISO8601-with-Z at boundary, canned bark_timeline query deferred. Remaining: Morgan's telemetry-retention call (keep tb2 ≥ freeze-RCA window), Phase 4 archival approval. No backfill (standing).
- [x] **App slice SHIPPED Build 156 (2026-09-01):** bark rows labeled with `bark_type` ("Distress bark" etc.) in live + history feeds — lenient dig (top-level/data/payload, emotion fallback for pre-8068ef3 robots, unclassified suppressed) in notifications_provider `_barkTypeLabel`

---

## BUILD 40 VALIDATION CHECKLIST

### ✅ Code Changes Reviewed (Implemented in Build 40)
- [x] Mission field names fixed (`mission_name`→`mission_id`, `stage`→`stage_number`)
- [x] AI confidence display bridge added (`update_dog_behavior()` call)
- [x] Servo tracking auto-enable in COACH mode
- [x] MP3 download URL construction (relay relative path fix)
- [x] Coach progress/reward events added
- [x] GET /missions endpoint added

### ✅ Live Testing Complete
- [x] Mission progress events reaching relay with correct field names
- [x] Video overlay showing "sit 34%" confidence labels
- [x] Servo tracking checkbox working in app
- [x] MP3 upload flow working end-to-end (app → relay → robot)
- [x] Coach mode events visible in app

---

## PRIORITY 1: Unknowns (Need User Input)

### ❓ Coach Mode Status
- [x] Is bark detection filtering working? (claps/voice rejected?)
- [x] Are pose thresholds accurate? (sitting ≠ down/crosses?)
- [x] Full coaching session end-to-end tested?

### ❓ Silent Guardian Status
- [x] Bark → intervention flow working?
- [x] Escalation and cooldown working?

### ❓ App/Relay Integration
- [x] Is relay forwarding events correctly?
- [x] Is app displaying mission progress?
- [x] Are WebRTC video streams stable?

### ✅ Hardware Status
- [x] Servo calibration accurate (needs tweaking per unit)
- [x] Treat dispenser working reliably
- [x] Audio playback consistent

---

## PRIORITY 2: Verified Working (From Recent Builds)

### ✅ Build 40 (Feb 2, 2026)
- [x] Mission field names standardized
- [x] AI detection bridge to video overlay
- [x] Servo tracking auto-enable
- [x] Download song URL construction
- [x] Coach progress events
- [x] GET /missions REST endpoint

### ✅ Build 38 (Feb 1, 2026)
- [x] Video overlay race condition fix
- [x] Bounding boxes for unidentified dogs
- [x] Dog identification conservative defaults ("Dog" label)
- [x] Nudge servo tracking (gentle, 2°/sec max)
- [x] MP3 download via HTTP (not WebSocket)

### ✅ Build 36 (Jan 31, 2026)
- [x] Mission name aliases (stay_training → sit_training)
- [x] Frame freshness check (<500ms)
- [x] Faster detection (1.5s + 50% presence)
- [x] Default "Dog" label when ArUco unavailable

### ✅ Build 35 (Jan 31, 2026)
- [x] Schedule API with dog_id, schedule_id, type fields
- [x] Schedule types: once/daily/weekly
- [x] Auto-disable "once" schedules after execution

### ✅ Build 34 (Jan 31, 2026)
- [x] Mission presence detection fixed
- [x] Dog identification regression fixed
- [x] Video overlay emoji removal
- [x] Mode sync events (mode_changed)
- [x] Servo safety limits

### ✅ Earlier Fixes (Jan 2026)
- [x] Threading race conditions (timestamp validation)
- [x] Bark bandpass filter (400-4000Hz)
- [x] Pose thresholds (0.75 for lie/cross)
- [x] Presence-based detection (3s + 66%)
- [x] Retry on first failure
- [x] WIM-Z audio feedback system

---

## PRIORITY 3: Needs Rework/Testing

### Weekly Summary System (`core/weekly_summary.py`)
**Status:** Tested, not 100% accurate
- [x] Tested with live data (not fully accurate)
- [ ] Verify `generate_weekly_report()` returns accurate data
- [ ] Test API endpoints: `GET /reports/weekly`, `GET /reports/trends`

### Mission Scheduler (`core/mission_scheduler.py`)
**Status:** Implemented, type logic added in Build 35, NOT TESTED
- [ ] Auto-scheduling not yet tested
- [ ] Test time window enforcement
- [ ] Verify missions auto-start correctly

---

## PRIORITY 4: Future Enhancements

### Analytics System
- [ ] Daily summary endpoint
- [ ] Bark frequency trends
- [x] Treat usage stats (treat inventory tracking implemented)
- [ ] Bone score rating (1-5)

### Session Management
- [ ] 8-hour session tracking
- [ ] Session reset at midnight
- [ ] Max 11 treats enforcement

### Photography
- [ ] Burst mode
- [ ] Quality scoring
- [ ] Best photo selection

### Push Notifications (BUILD 41)
- [x] AWS SNS notification service created (`services/cloud/notification_service.py`)
- [x] API endpoints added (`/notifications/*`)
- [ ] Install boto3: `pip install boto3`
- [ ] Configure AWS credentials (see setup below)
- [ ] Test SMS sending
- [ ] Integrate with mission_complete events
- [ ] Integrate with bark_alert events
- [ ] Integrate with low_battery events

---

## AWS SNS Setup (Push Notifications)
```bash
# 1. Install boto3
pip install boto3

# 2. Configure AWS credentials (choose one method)
# Method A: AWS CLI
aws configure
# Enter: Access Key ID, Secret Key, Region (us-east-1 recommended for SMS)

# Method B: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# 3. Test the service
curl http://localhost:8000/notifications/health

# 4. Add a subscriber
curl -X POST http://localhost:8000/notifications/subscribers \
  -H "Content-Type: application/json" \
  -d '{"user_id": "morgan", "phone_number": "+15551234567"}'

# 5. Send test notification
curl -X POST "http://localhost:8000/notifications/test?user_id=morgan"
```

**AWS SMS Sandbox Note:**
New AWS accounts are in SMS sandbox mode. To send SMS:
- Option A: Verify destination phone numbers in AWS Console → SNS → Text messaging
- Option B: Request production access (takes 1-2 days approval)

---

## Quick Test Commands
```bash
# Restart service
sudo systemctl restart treatbot

# Monitor logs
journalctl -u treatbot -f | grep -i "mission\|coach\|bark\|pose"

# Check mode
curl http://localhost:8000/mode

# Test missions endpoint
curl http://localhost:8000/missions

# Force coach mode
curl -X POST http://localhost:8000/mode/set -H "Content-Type: application/json" -d '{"mode": "COACH"}'
```

---

## Key Files Reference

| Purpose | File |
|---------|------|
| Main entry | `main_treatbot.py` |
| Mission engine | `orchestrators/mission_engine.py` |
| Coach mode | `orchestrators/coaching_engine.py` |
| Silent Guardian | `modes/silent_guardian.py` |
| Detector | `services/perception/detector.py` |
| Video overlay | `services/streaming/video_track.py` |
| Pan/tilt | `services/motion/pan_tilt.py` |
| Relay client | `services/cloud/relay_client.py` |

---

## Dropped Features

- **IR Navigation/Docking** - Hardware caused Pi startup failures

## ✅ Previously "Dropped" - Now Implemented

- **Direct LAN Connection** - Phone connects directly to robot WiFi (WIMZ-*) without relay

---

*Updated: June 2026 — Build 106. Added current open-items (reliability, validation, SG design, data refactor); fleet now 5 units.*
