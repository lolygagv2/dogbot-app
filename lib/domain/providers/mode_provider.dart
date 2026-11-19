import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/robot_state.dart';
import 'robot_state_provider.dart';
import 'connection_provider.dart';
import 'telemetry_provider.dart';
import '../../l10n/l10n.dart';
import 'l10n_provider.dart';

/// Robot modes — exactly the five values of ROBOT-STATE v2 `mode`.
/// Sleep is NOT a mode: it is the separate `asleep` flag ([ModeState.asleep],
/// `set_sleep`). No aliases: any other string is not a mode.
enum RobotMode {
  idle('idle', 'Idle'),
  manual('manual', 'Manual'),
  silentGuardian('silent_guardian', 'Silent Guardian'),
  coach('coach', 'Coach'),
  mission('mission', 'Mission');

  final String value;
  final String label;
  const RobotMode(this.value, this.label);

  static RobotMode fromString(String value) =>
      tryFromString(value) ?? RobotMode.idle;

  /// Returns null instead of defaulting to idle for unrecognized strings.
  /// Use this for external data where an unrecognized mode should be ignored.
  static RobotMode? tryFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final mode in RobotMode.values) {
      if (mode.value == value) return mode;
    }
    connTrace('mode-unrecognized', value);
    return null;
  }
}

/// Mode + sleep state. Under ROBOT-STATE v2 the relay's `robot_state`
/// record is the authority; a pending value is only shown while the
/// app's own command is waiting for its `command_result`.
class ModeState {
  final RobotMode currentMode;
  final RobotMode? pendingMode;      // Mode we're waiting for confirmation
  final bool isChanging;             // True while waiting for confirmation
  final String? error;               // Error message if mode change failed
  final DateTime? errorTime;         // When error occurred (for auto-dismiss)
  final String? activeMissionId;     // ID of active mission (if any)
  final String? activeMissionName;   // Name of active mission (if any)
  final bool isModeLocked;           // True when mission is active (mode can't change)
  final RobotMode previousPortraitMode; // v1.3: Stored when entering landscape/mission

  /// `robot_state.asleep`. Not a mode: an asleep robot's mode is "idle".
  final bool asleep;

  /// The value a `set_sleep` in flight asked for; null when none is.
  final bool? pendingAsleep;

  const ModeState({
    this.currentMode = RobotMode.idle,
    this.pendingMode,
    this.isChanging = false,
    this.error,
    this.errorTime,
    this.activeMissionId,
    this.activeMissionName,
    this.isModeLocked = false,
    this.previousPortraitMode = RobotMode.idle,
    this.asleep = false,
    this.pendingAsleep,
  });

  ModeState copyWith({
    RobotMode? currentMode,
    RobotMode? pendingMode,
    bool? isChanging,
    String? error,
    DateTime? errorTime,
    String? activeMissionId,
    String? activeMissionName,
    bool? isModeLocked,
    RobotMode? previousPortraitMode,
    bool? asleep,
    bool? pendingAsleep,
    bool clearPending = false,
    bool clearError = false,
    bool clearMission = false,
    bool clearPendingAsleep = false,
  }) {
    return ModeState(
      currentMode: currentMode ?? this.currentMode,
      pendingMode: clearPending ? null : (pendingMode ?? this.pendingMode),
      isChanging: isChanging ?? this.isChanging,
      error: clearError ? null : (error ?? this.error),
      errorTime: clearError ? null : (errorTime ?? this.errorTime),
      activeMissionId: clearMission ? null : (activeMissionId ?? this.activeMissionId),
      activeMissionName: clearMission ? null : (activeMissionName ?? this.activeMissionName),
      isModeLocked: isModeLocked ?? this.isModeLocked,
      previousPortraitMode: previousPortraitMode ?? this.previousPortraitMode,
      asleep: asleep ?? this.asleep,
      pendingAsleep:
          clearPendingAsleep ? null : (pendingAsleep ?? this.pendingAsleep),
    );
  }

  /// The robot is asleep (`robot_state.asleep`).
  bool get isAsleep => asleep;

  /// True while a `set_sleep` is waiting for its result.
  bool get isSleepChanging => pendingAsleep != null;

  /// True if a mission is currently active
  bool get isMissionActive => activeMissionId != null;

  /// Check if mode change is allowed
  bool canChangeMode() => !isModeLocked;

  /// The mode to display in UI (confirmed mode only — no optimistic updates)
  RobotMode get displayMode => currentMode;

  /// True if a mode switch is in progress (pending confirmation)
  bool get isSwitching => isChanging && pendingMode != null;

  /// True if there's a recent error (within 5 seconds)
  bool get hasRecentError {
    if (error == null || errorTime == null) return false;
    return DateTime.now().difference(errorTime!).inSeconds < 5;
  }
}

/// Provider for mode state
final modeStateProvider =
    StateNotifierProvider<ModeStateNotifier, ModeState>((ref) {
  return ModeStateNotifier(ref);
});

/// Mode state notifier.
///
/// ROBOT-STATE v2: the relay's `robot_state` record (E2/H1, via
/// [robotStateProvider]) decides mode, asleep and the mission lock. The
/// app's own commands — `set_mode` (C1) and `set_sleep` (C3) — carry a
/// command_id and are settled by their `command_result`: nothing is
/// assumed on silence, and a refusal ("robot_offline", "robot_timeout",
/// "invalid_mode") is shown and dropped. Nothing is queued or retried.
///
/// On the local-AP socket there is no relay record. There the mode comes
/// from the robot's `connected` / `initial_status` sync, the command
/// results, and — guarded by the user's last selection (Build 50v2, the
/// robot's status echoes can be stale) — status/telemetry frames.
class ModeStateNotifier extends StateNotifier<ModeState> {
  final Ref _ref;

  AppLocalizations get _l => _ref.read(l10nProvider);
  final _uuid = const Uuid();
  Timer? _timeoutTimer;
  Timer? _sleepTimeoutTimer;
  Timer? _errorDismissTimer;
  StreamSubscription? _wsSubscription;

  /// How long a tap shows pending: 10000 ms (Morgan, 2026-11-19 — not
  /// the brief's 5000: a phone on weak Wi-Fi can take longer than 5 s
  /// for the round trip). Past it the selector reverts and shows an
  /// error, so the status is never frozen; a state record that arrives
  /// later is still rendered.
  static const Duration _confirmationTimeout = Duration(seconds: 10);

  /// Mode shown before the set_mode in flight (to undo a local-AP
  /// assumption if the robot's late answer is a refusal).
  RobotMode? _modeBeforeCommand;

  /// command_id of the set_mode / set_sleep waiting for its result.
  String? _modeCommandId;
  String? _sleepCommandId;

  /// True when the app talks to the robot through the relay. Then mode,
  /// asleep and the mission lock are rendered ONLY from `robot_state`
  /// (E2/H1); a command_result merely ends the pending state. On the
  /// local-AP socket (no relay record) the pre-v2 sources still apply.
  bool get _cloud => !_ref.read(robotStateProvider.notifier).isLocalMode;

  /// `state_version` when the set_mode / set_sleep in flight was sent:
  /// pending ends as soon as the record's version passes it.
  int _versionAtModeTap = 0;
  int _versionAtSleepTap = 0;
  int _lastStateVersion = 0;

  /// Local-AP guard (Build 50v2): the mode the user explicitly selected.
  /// While set, status/telemetry echoes that don't match are rejected.
  RobotMode? _userSelectedMode;

  ModeStateNotifier(this._ref) : super(const ModeState()) {
    _listenToModeEvents();
    _getInitialMode();
    _ref.listen<RobotState?>(robotStateProvider, (prev, next) {
      if (next != null) _applyRobotState(next);
    }, fireImmediately: true);
  }

  void _logModeChange(RobotMode oldMode, RobotMode newMode, String source) {
    if (oldMode == newMode) return;
    connTrace('mode', '${oldMode.value} -> ${newMode.value} | $source');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROBOT-STATE v2 — the authority
  // ─────────────────────────────────────────────────────────────────────────

  void _applyRobotState(RobotState rs) {
    _userSelectedMode = null;
    _lastStateVersion = rs.stateVersion;
    final mode = RobotMode.tryFromString(rs.mode) ?? state.currentMode;
    _logModeChange(state.currentMode, mode, 'robot_state v${rs.stateVersion}');

    // Pending ends when state_version has increased since the tap.
    final confirmsPending =
        state.isChanging && rs.stateVersion > _versionAtModeTap;
    if (confirmsPending) _cancelTimeout();
    final confirmsSleep =
        state.pendingAsleep != null && rs.stateVersion > _versionAtSleepTap;
    if (confirmsSleep) _sleepTimeoutTimer?.cancel();

    final locked = mode == RobotMode.mission;
    state = state.copyWith(
      currentMode: mode,
      asleep: rs.asleep,
      isModeLocked: locked,
      // Mission name/id are dropped when the robot leaves mission mode.
      clearMission: !locked && state.currentMode == RobotMode.mission,
      isChanging: confirmsPending ? false : null,
      clearPending: confirmsPending,
      clearError: confirmsPending || confirmsSleep,
      clearPendingAsleep: confirmsSleep,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL-AP GUARD (no relay record)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if a status/telemetry echo should be BLOCKED.
  bool _shouldBlockExternalMode(RobotMode incomingMode) {
    if (_userSelectedMode == null) return false;
    if (incomingMode == _userSelectedMode) return false;
    return true;
  }

  /// Get initial mode from telemetry (only on startup, before user interacts)
  void _getInitialMode() {
    if (_cloud) return;
    final telemetry = _ref.read(telemetryProvider);
    if (telemetry.mode.isNotEmpty) {
      final initialMode = RobotMode.tryFromString(telemetry.mode);
      if (initialMode != null && initialMode != state.currentMode) {
        _logModeChange(state.currentMode, initialMode, 'init_telemetry');
        state = state.copyWith(currentMode: initialMode);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEBSOCKET EVENT HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  void _listenToModeEvents() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen((event) {
      if (event.type == 'command_result') {
        final id = event.data['command_id']?.toString();
        if (id == null) return;
        if (id == _modeCommandId) {
          _onModeResult(event.data, expired: event.isExpiredCommandResult);
        } else if (id == _sleepCommandId) {
          _onSleepResult(event.data, expired: event.isExpiredCommandResult);
        }
      } else if (event.type == 'mode' ||
          event.type == 'status_update' ||
          event.type == 'battery' ||
          event.type == 'telemetry') {
        final mode = event.data['mode'] as String?;
        if (mode != null) _handleModeEcho(mode);
      } else if (event.type == 'mission_progress') {
        // Build 146: replayed (buffered) mission events are history, not live
        // state — a stale mission_progress from the store-and-forward buffer
        // must not flip the live mode UI (or worse, trigger sends).
        if (!event.buffered) _handleMissionProgress(event.data);
      } else if (event.type == 'mission_complete' || event.type == 'mission_stopped') {
        if (!event.buffered) _handleMissionEnded();
      } else if (event.type == 'connected' || event.type == 'initial_status') {
        if (!_cloud) _handleAuthoritativeSync(event);
      } else if (!_cloud &&
          (event.type == 'error' || event.type == 'webrtc_error') &&
          _saysRobotAsleep(event.data)) {
        // The robot declined something because it is asleep.
        connTrace('mode-robot-asleep', event.type);
        if (!state.asleep) state = state.copyWith(asleep: true);
      }
    });
  }

  static bool _saysRobotAsleep(Map<String, dynamic> data) {
    for (final k in const ['code', 'error', 'error_code', 'reason', 'message']) {
      if (data[k]?.toString().toLowerCase().contains('robot_asleep') == true) {
        return true;
      }
    }
    return false;
  }

  /// `command_result` of our set_mode (C1): result {mode, session_dog_id}.
  void _onModeResult(Map<String, dynamic> data, {bool expired = false}) {
    _cancelTimeout();
    _modeCommandId = null;
    final success = data['success'] == true;
    final result = data['result'];
    final error = data['error']?.toString();
    connTrace('mode-result',
        'success=$success error=$error result=$result ms=${data['duration_ms']}');
    if (!success) {
      // Undo a mode taken on silence (local-AP) — the robot refused it.
      final before = _modeBeforeCommand;
      if (!_cloud && before != null && !state.isChanging) {
        state = state.copyWith(currentMode: before);
      }
      _failModeChange(_errorText(error, expired: expired));
      return;
    }
    final mode = RobotMode.tryFromString(
            result is Map ? result['mode']?.toString() : null) ??
        state.pendingMode ??
        state.currentMode;
    if (_cloud) {
      // The result only ends pending; the mode shown is the record's.
      state = state.copyWith(
          isChanging: false, clearPending: true, clearError: true);
      if (_lastStateVersion <= _versionAtModeTap) {
        unawaited(_ref.read(robotStateProvider.notifier).refresh());
      }
      return;
    }
    _logModeChange(state.currentMode, mode, 'command_result');
    state = state.copyWith(
      currentMode: mode,
      isChanging: false,
      clearPending: true,
      clearError: true,
      isModeLocked: mode == RobotMode.mission,
    );
  }

  /// `command_result` of our set_sleep (C3): result {asleep, mode}.
  void _onSleepResult(Map<String, dynamic> data, {bool expired = false}) {
    _sleepTimeoutTimer?.cancel();
    _sleepCommandId = null;
    final success = data['success'] == true;
    final result = data['result'];
    final error = data['error']?.toString();
    connTrace('sleep-result',
        'success=$success error=$error result=$result ms=${data['duration_ms']}');
    if (!success) {
      state = state.copyWith(
        clearPendingAsleep: true,
        error: _errorText(error, expired: expired),
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      return;
    }
    if (_cloud) {
      state = state.copyWith(clearPendingAsleep: true, clearError: true);
      if (_lastStateVersion <= _versionAtSleepTap) {
        unawaited(_ref.read(robotStateProvider.notifier).refresh());
      }
      return;
    }
    final asleep = (result is Map && result['asleep'] is bool)
        ? result['asleep'] as bool
        : (state.pendingAsleep ?? state.asleep);
    final mode = RobotMode.tryFromString(
        result is Map ? result['mode']?.toString() : null);
    state = state.copyWith(
      asleep: asleep,
      currentMode: mode,
      clearPendingAsleep: true,
      clearError: true,
    );
  }

  /// The contract's exact refusal strings, in the user's language.
  String _errorText(String? error, {bool expired = false}) {
    if (expired) return _l.cmdErrRobotBusy;
    switch (error) {
      case 'expired':
        return _l.cmdErrRobotBusy;
      case 'robot_offline':
        return _l.modeErrRobotOffline;
      case 'robot_timeout':
        return _l.modeErrRobotTimeout;
      case 'invalid_mode':
        return _l.modeErrInvalidMode;
      default:
        return _l.modeErrCommandFailed(error ?? '?');
    }
  }

  void _failModeChange(String message) {
    _userSelectedMode = null;
    state = state.copyWith(
      isChanging: false,
      clearPending: true,
      error: message,
      errorTime: DateTime.now(),
    );
    _scheduleErrorDismiss();
  }

  /// Build 146: robot-authoritative mode sync on (re)connect. /ws/local sends
  /// `connected` (current_mode) and `initial_status` (data.system_state) on
  /// every connect. The app adopts the robot's mode and sends NOTHING.
  void _handleAuthoritativeSync(WsEvent event) {
    final rawState = event.type == 'connected'
        ? event.data['current_mode']
        : event.data['system_state'];
    // system_state may be a bare mode string or an object carrying one.
    final modeValue = rawState is Map
        ? (rawState['mode'] ?? rawState['current_mode'])?.toString()
        : rawState?.toString();
    if (modeValue == null || modeValue.isEmpty) return;
    final mode = RobotMode.tryFromString(modeValue);
    if (mode == null) return;

    connTrace('mode-robot-sync', '${event.type} mode=$modeValue '
        '(was=${state.currentMode.value} userSel=${_userSelectedMode?.value})');
    _cancelTimeout();
    _modeCommandId = null;
    _userSelectedMode = null;
    if (mode != state.currentMode || state.isChanging) {
      _logModeChange(state.currentMode, mode, 'robot_sync_${event.type}');
      state = state.copyWith(
        currentMode: mode,
        isChanging: false,
        clearPending: true,
        clearError: true,
      );
    }
  }

  /// A mode carried by a status / battery / telemetry / mode frame. Only
  /// used until a `robot_state` record exists (i.e. on the local-AP
  /// socket), and never to settle a command — the command_result does that.
  void _handleModeEcho(String modeValue) {
    if (_cloud || state.isChanging) return;
    final mode = RobotMode.tryFromString(modeValue);
    if (mode == null) return;
    if (_shouldBlockExternalMode(mode)) return;
    if (mode != state.currentMode) {
      _logModeChange(state.currentMode, mode, 'ws_echo');
      state = state.copyWith(currentMode: mode);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MISSION HANDLING
  // ─────────────────────────────────────────────────────────────────────────

  /// Handle mission_progress events to lock/unlock mode
  void _handleMissionProgress(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final missionId = data['mission_id']?.toString() ?? data['id']?.toString();
    final missionName = data['mission'] as String? ?? data['mission_name'] as String? ?? missionId;

    if (_cloud) {
      // Through the relay the mode and its lock come from robot_state;
      // mission events only supply the mission's name for the chip.
      if (missionId != null &&
          action != 'completed' &&
          action != 'stopped' &&
          state.activeMissionId != missionId) {
        state = state.copyWith(
            activeMissionId: missionId, activeMissionName: missionName);
      }
      return;
    }
    switch (action) {
      case 'started':
        _logModeChange(state.currentMode, RobotMode.mission, 'mission_started');
        _userSelectedMode = null; // mission takes over
        state = state.copyWith(
          currentMode: RobotMode.mission,
          activeMissionId: missionId,
          activeMissionName: missionName,
          isModeLocked: true,
          isChanging: false,
          clearPending: true,
          clearError: true,
        );
        break;
      case 'completed':
      case 'stopped':
        _handleMissionEnded();
        break;
      default:
        // Only update mission info if already in mission mode
        if (state.currentMode == RobotMode.mission && missionId != null) {
          if (state.activeMissionId != missionId) {
            state = state.copyWith(
              activeMissionId: missionId,
              activeMissionName: missionName,
            );
          }
        }
        break;
    }
  }

  /// Handle mission ended (completed or stopped). UI-only (Build 146): the
  /// robot exits its own missions; the app mirrors and sends nothing.
  void _handleMissionEnded() {
    if (_cloud) return; // robot_state decides
    _logModeChange(state.currentMode, RobotMode.idle, 'mission_ended');
    _userSelectedMode = RobotMode.idle;
    state = state.copyWith(
      currentMode: RobotMode.idle,
      isModeLocked: false,
      clearMission: true,
      isChanging: false,
      clearPending: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER-INITIATED COMMANDS
  // ─────────────────────────────────────────────────────────────────────────

  /// C1 set_mode. [reason] is the app's context ("dropdown", "drive_enter",
  /// …) and goes out as `data.reason`; the relay sets `source` itself.
  /// [dogId] null = the session uses the selected dog (may be none — no
  /// mode needs a dog).
  Future<void> setMode(RobotMode mode,
      {String reason = 'dropdown', String? dogId}) async {
    // Don't change if mode is locked (mission active)
    if (state.isModeLocked && mode != RobotMode.mission) {
      state = state.copyWith(
        error: _l.modeErrMissionActive,
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      return;
    }

    // Don't change if already in this mode
    if (state.currentMode == mode && !state.isChanging) return;

    _cancelTimeout();

    if (_ref.read(connectionProvider).isDemoMode) {
      state = state.copyWith(
          currentMode: mode, isChanging: false, clearPending: true, clearError: true);
      return;
    }

    final commandId = _uuid.v4();
    final sent = _ref.read(websocketClientProvider).sendModeCommand(
          mode.value,
          commandId: commandId,
          dogId: dogId,
          reason: reason,
        );
    connTrace('mode-set', '${mode.value} reason=$reason dog=$dogId sent=$sent');
    if (!sent) {
      _modeCommandId = null;
      _failModeChange(_l.errNotConnectedToRobot);
      return;
    }

    _modeCommandId = commandId;
    _versionAtModeTap = _lastStateVersion;
    _modeBeforeCommand = state.currentMode;
    _userSelectedMode = mode;
    state = state.copyWith(
      pendingMode: mode,
      isChanging: true,
      clearError: true,
    );
    _timeoutTimer = Timer(_confirmationTimeout, _onTimeout);
  }

  /// C3 set_sleep. Sleep is not a mode: asleep forces mode "idle" on the
  /// robot, waking leaves it "idle".
  Future<void> setSleep(bool asleep, {String? reason}) async {
    if (state.pendingAsleep != null) return;
    if (state.asleep == asleep) return;

    if (_ref.read(connectionProvider).isDemoMode) {
      state = state.copyWith(
        asleep: asleep,
        currentMode: asleep ? RobotMode.idle : null,
      );
      return;
    }

    final commandId = _uuid.v4();
    final sent = _ref
        .read(websocketClientProvider)
        .sendSleepCommand(asleep, commandId: commandId, reason: reason);
    connTrace('sleep-set', 'asleep=$asleep reason=$reason sent=$sent');
    if (!sent) {
      state = state.copyWith(
        error: _l.errNotConnectedToRobot,
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      return;
    }
    _sleepCommandId = commandId;
    _versionAtSleepTap = _lastStateVersion;
    state = state.copyWith(pendingAsleep: asleep, clearError: true);
    _sleepTimeoutTimer?.cancel();
    _sleepTimeoutTimer = Timer(_confirmationTimeout, () {
      if (!mounted || state.pendingAsleep == null) return;
      // _sleepCommandId is kept: a late result still settles it.
      connTrace('sleep-timeout', 'pending=${state.pendingAsleep}');
      if (!_cloud) {
        // No relay record to ask (local-AP): take the command as done.
        state = state.copyWith(
            asleep: state.pendingAsleep, clearPendingAsleep: true);
        return;
      }
      state = state.copyWith(
        clearPendingAsleep: true,
        error: _l.modeErrNoAnswer,
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      unawaited(_ref.read(robotStateProvider.notifier).refresh());
    });
  }

  /// v1.3: Store current portrait mode before entering landscape/mission
  void storePortraitMode() {
    // Without a relay record (local-AP) telemetry is the better witness
    // of the robot's actual mode than a possibly-stale cached value.
    final telemetryMode = _cloud
        ? null
        : RobotMode.tryFromString(_ref.read(telemetryProvider).mode);
    final actual = telemetryMode ?? state.currentMode;

    // Only store portrait-valid modes
    final toStore = (actual == RobotMode.idle ||
        actual == RobotMode.silentGuardian ||
        actual == RobotMode.coach)
        ? actual
        : RobotMode.idle;
    state = state.copyWith(previousPortraitMode: toStore);
  }

  /// v1.3: Restore previous portrait mode when exiting landscape/mission
  Future<void> restorePortraitMode({String reason = 'drive_exit_restore'}) async {
    await setMode(state.previousPortraitMode, reason: reason);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIMEOUT HANDLING
  // ─────────────────────────────────────────────────────────────────────────

  /// No command_result within [_confirmationTimeout]. The spinner ends —
  /// the status must never sit frozen — but nothing is re-sent, and
  /// [_modeCommandId] is kept so a late result still settles the mode.
  ///
  /// With a relay record the app asks the relay what the robot is
  /// actually in (H1) instead of guessing; any later `robot_state` also
  /// corrects it. Without one (local-AP) there is nobody to ask, so the
  /// command is taken as done, as before v2.
  void _onTimeout() {
    if (!mounted || !state.isChanging) return;
    final pending = state.pendingMode;
    connTrace('mode-timeout',
        'pending=${pending?.value} cloud=$_cloud');
    if (!_cloud && pending != null) {
      _logModeChange(state.currentMode, pending, 'timeout_accepted');
      state = state.copyWith(
        currentMode: pending,
        isChanging: false,
        clearPending: true,
        clearError: true,
      );
      return;
    }
    _failModeChange(_l.modeErrNoAnswer);
    unawaited(_ref.read(robotStateProvider.notifier).refresh());
  }

  @visibleForTesting
  void debugFireTimeout() => _onTimeout();

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _scheduleErrorDismiss() {
    _errorDismissTimer?.cancel();
    _errorDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        state = state.copyWith(clearError: true);
      }
    });
  }

  /// Set mode by string value
  Future<void> setModeByString(String modeValue, {String reason = 'dropdown'}) async {
    final mode = RobotMode.tryFromString(modeValue);
    if (mode == null) return; // Ignore unrecognized mode strings
    await setMode(mode, reason: reason);
  }

  /// Set to manual mode
  Future<void> setManualMode({String reason = 'drive_enter'}) async {
    await setMode(RobotMode.manual, reason: reason);
  }

  /// Clear error manually
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _cancelTimeout();
    _sleepTimeoutTimer?.cancel();
    _errorDismissTimer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for displayed mode (optimistic)
final displayModeProvider = Provider<RobotMode>((ref) {
  return ref.watch(modeStateProvider).displayMode;
});

/// Provider for mode error (for toast display)
final modeErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(modeStateProvider);
  return state.hasRecentError ? state.error : null;
});

/// Provider for checking if mission is active (mode locked)
final isMissionActiveProvider = Provider<bool>((ref) {
  return ref.watch(modeStateProvider).isMissionActive;
});

/// Provider for active mission name
final activeMissionNameProvider = Provider<String?>((ref) {
  return ref.watch(modeStateProvider).activeMissionName;
});

/// Legacy provider for mode control (delegates to new state notifier)
final modeControlProvider = Provider<ModeControl>((ref) {
  return ModeControl(ref);
});

/// Mode control - legacy API that delegates to state notifier
class ModeControl {
  final Ref _ref;

  ModeControl(this._ref);

  /// Set robot mode
  void setMode(RobotMode mode, {String reason = 'dropdown'}) {
    _ref.read(modeStateProvider.notifier).setMode(mode, reason: reason);
  }

  /// Set mode by string value
  void setModeByString(String modeValue, {String reason = 'dropdown'}) {
    _ref.read(modeStateProvider.notifier).setModeByString(modeValue, reason: reason);
  }

  /// Set to manual mode (default on connect)
  void setManualMode({String reason = 'drive_enter'}) {
    _ref.read(modeStateProvider.notifier).setManualMode(reason: reason);
  }
}

/// True while the robot is asleep (`robot_state.asleep`; main screen + demo view).
final robotAsleepProvider = Provider<bool>((ref) {
  return ref.watch(modeStateProvider).isAsleep;
});
