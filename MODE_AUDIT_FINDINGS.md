# MODE_AUDIT_FINDINGS.md
## WIM-Z App — Mode Switching Diagnostic Audit (v1.3)

**Date:** 2026-02-22
**Auditor:** Claude (automated code trace)
**Scope:** App-side mode switching only (no robot/relay code)

---

## Reported Issues

1. Selecting Manual from dropdown briefly switches to manual then immediately reverts to idle
2. Pressing Drive triggers "Switching to Manual Mode" but robot stays in idle
3. **Status:** Currently NOT manifesting. Root cause unknown.

---

## Audit 1: Drive Button Press Flow

### Traced Path

1. **Home screen** — `context.push('/drive')` (home_screen.dart, portrait controls)
2. **DriveScreen.initState()** — `addPostFrameCallback` (drive_screen.dart:34)
3. **storePortraitMode()** — stores current mode before landscape (mode_provider.dart)
4. **_ensureManualMode()** — checks `currentMode != manual`, calls `setManualMode(source: 'drive_enter')` (drive_screen.dart:57-64)
5. **ModeStateNotifier.setMode()** — sets `pendingMode = manual`, `isChanging = true`, sends WebSocket command (mode_provider.dart:359-405)
6. **WebSocketClient.sendModeCommand()** — sends `{"type":"command","command":"set_mode","data":{"mode":"manual","source":"drive_enter","timestamp":"..."}}` (websocket_client.dart:432-438)

### Findings

- `set_mode` is sent **once** per Drive entry (guarded by `_modeChangeRequested` flag)
- No debounce guard against rapid Drive re-taps (tapping Drive twice fast could send two commands) — **low risk** since GoRouter prevents duplicate pushes
- No race condition between mode dropdown and Drive button — they operate on separate screens

**Verdict:** Drive button flow is clean. Single command sent, no duplication.

---

## Audit 2: Mode State Management

### State Model (mode_provider.dart:29-94)

| Field | Role | Updated By |
|-------|------|-----------|
| `currentMode` | Robot-confirmed mode | WebSocket events, telemetry sync |
| `pendingMode` | User-requested mode (optimistic) | User clicks dropdown/drive |
| `isChanging` | True while waiting for confirmation | Set on user action, cleared on confirmation/timeout |
| `displayMode` | Shows `pendingMode ?? currentMode` | Derived property |

### Race Condition: status_update Overwriting User Selection

**Scenario:** User selects "manual" → robot sends `status_update` with `mode: idle` before confirming manual.

**Protections in place:**
1. **Build 36 cooldown** (mode_provider.dart:136-140): 2-second window after user click during which external mode updates are **blocked entirely**.
2. **isChanging guard** (mode_provider.dart:133): Telemetry sync skips while `isChanging = true`.
3. **Confirmation handler** (mode_provider.dart:286-356): During cooldown, only accepts the expected pending mode; ignores all other modes.

**Could this cause the reported behavior?**
- **Pre-Build 36:** YES. A `status_update` with `mode: idle` arriving between user click and robot confirmation would overwrite `currentMode` to idle. Since `pendingMode` gets cleared on mismatch, `displayMode` would revert.
- **Post-Build 36:** NO. The 2-second cooldown blocks this path entirely.

**Status:** FIXED (Build 36). Dormant — would only reappear if cooldown is bypassed.

---

## Audit 3: Confirmation Timeout Revert

### The 10-Second Timeout Path (mode_provider.dart:409-435)

```
User clicks Manual → pendingMode=manual, isChanging=true
...10 seconds pass with no matching confirmation...
_onTimeout() fires:
  1. Checks telemetry for actual mode
  2. If telemetry shows "manual" → confirms (silent success)
  3. If telemetry shows "idle" → reverts to idle, shows error toast
```

**Could this cause the reported behavior?**
- YES, but only if the robot never confirms the mode change within 10 seconds.
- This is a **robot-side issue** if the robot doesn't respond to `set_mode`.
- The app correctly shows an error message ("Mode change timed out") when this happens.

**Status:** By design. The timeout is a safety net, not a bug.

---

## Audit 4: WebSocket Reconnection

### Reconnection Flow (websocket_client.dart:131-175, connection_provider.dart:222-229)

1. WebSocket disconnects (network, relay restart, etc.)
2. Auto-reconnect with exponential backoff (max 5 attempts)
3. On reconnect: `_requestRobotStatus()` called
4. Robot responds with current status including mode
5. Telemetry provider updates mode from status response
6. Mode provider syncs from telemetry (every 2s)

**Critical finding:** The app does **NOT** re-send the user's last mode on reconnect. It accepts whatever mode the robot is in.

**Could this cause the reported behavior?**
- YES, if: Robot resets to idle on reconnect AND the status_update arrives right after user clicked a mode.
- The 2-second cooldown protects against this during active mode changes.
- But if reconnect happens **outside** a mode change, the mode silently reverts.

**Status:** By design (app defers to robot's actual mode). Not a bug but could confuse users if robot resets.

---

## Audit 5: Login Flow Differences

### Fresh Login vs Returning Session

**Fresh login** (login_screen.dart:48-76):
1. Auth via REST
2. WebSocket connect
3. Navigate to `/home`
4. ModeStateNotifier initializes with `idle`
5. `_getInitialMode()` reads telemetry — may be empty at this point
6. Telemetry sync corrects mode within 2 seconds

**Returning session** (app lifecycle resume, app.dart:498-499):
1. `webrtcProvider.resume()`
2. `connectionProvider.onAppResumed()`
3. Mode state from previous session **persists in memory**
4. Telemetry sync corrects to robot's actual mode within 2 seconds

**Stale state risk:**
- `previousPortraitMode` persists across app lifecycle changes — this is correct behavior
- `pendingMode` is cleared on timeout — no stale pending mode
- `activeMissionId` persists but is cleared on mission_complete events

**Status:** No stale state bugs found. The 2-second telemetry sync corrects any drift.

---

## Summary of Findings

| # | Finding | File:Line | Could Cause Reported Bug? | Status |
|---|---------|-----------|--------------------------|--------|
| 1 | Pre-Build-36 status_update race | mode_provider.dart:286-356 | YES (pre-Build 36) | FIXED (Build 36 cooldown) |
| 2 | 10s timeout reverts to idle | mode_provider.dart:409-435 | YES (if robot slow) | By design (safety net) |
| 3 | No mode re-send on reconnect | websocket_client.dart, connection_provider.dart | Indirectly | By design |
| 4 | Telemetry empty on fresh login | mode_provider.dart:154-159 | No (defaults to idle anyway) | Benign |
| 5 | Rapid Drive tap duplication | drive_screen.dart:57-64 | No (GoRouter guards) | N/A |

---

## Most Likely Root Cause of Reported Issues

**The reported behavior (mode briefly switching then reverting) was almost certainly caused by the pre-Build-36 race condition (#1):**

Before Build 36, the mode confirmation handler (`_handleModeConfirmation`) would accept ANY mode update from the robot, even during a pending user-initiated change. A stale `status_update` with `mode: idle` arriving right after the user clicked "Manual" would:
1. Set `currentMode = idle`
2. Clear `pendingMode` (mismatch)
3. Set `isChanging = false`
4. `displayMode` reverts to idle

Build 36 added a 2-second cooldown that **blocks all external mode updates** during user-initiated changes. This would explain why the issues are no longer manifesting.

---

## Recommendations

1. **No app-side code changes needed** — the Build 36 cooldown is the correct fix
2. **Robot-side investigation recommended** — verify the robot sends timely `mode_changed` events after `set_mode` commands
3. **Consider extending cooldown** from 2s to 3s if issues recur on slow networks
4. **Consider adding mode re-send on reconnect** as an enhancement (currently the app defers to robot's state)
