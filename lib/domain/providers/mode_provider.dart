import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import 'connection_provider.dart';
import 'telemetry_provider.dart';

/// Available robot modes
enum RobotMode {
  idle('idle', 'Idle'),
  manual('manual', 'Manual'),
  silentGuardian('silent_guardian', 'Silent Guardian'),
  coach('coach', 'Coach'),
  mission('mission', 'Mission');

  final String value;
  final String label;
  const RobotMode(this.value, this.label);

  static RobotMode fromString(String value) {
    return RobotMode.values.firstWhere(
      (mode) => mode.value == value.toLowerCase(),
      orElse: () => RobotMode.idle,
    );
  }

  /// Returns null instead of defaulting to idle for unrecognized strings.
  /// Use this for external data where an unrecognized mode should be ignored.
  static RobotMode? tryFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final mode in RobotMode.values) {
      if (mode.value == lower) return mode;
    }
    print('APP_MODE: WARNING unrecognized mode string: "$value"');
    return null;
  }
}

/// Mode state with optimistic update support
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
    bool clearPending = false,
    bool clearError = false,
    bool clearMission = false,
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
    );
  }

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

/// Provider for mode state with optimistic updates
final modeStateProvider =
    StateNotifierProvider<ModeStateNotifier, ModeState>((ref) {
  return ModeStateNotifier(ref);
});

/// Mode state notifier - handles optimistic updates and confirmations
///
/// Build 50v2: User mode selection is SOVEREIGN. Once the user clicks a mode,
/// no external event (battery, status_update, telemetry sync, mode_changed)
/// can override it. Only the user clicking a different mode or a mission lock
/// can change the displayed mode.
///
/// WHY: The robot's telemetry endpoint and battery events report stale
/// mode:idle because relay_client.py uses state.set_mode() instead of
/// mode_fsm.set_mode_override(). Until that robot-side bug is fixed, the
/// app cannot trust ANY external mode data. The robot IS in the correct
/// mode (visible on video overlay), but reports idle in telemetry/events.
///
/// Previous approaches (Builds 36-50) tried timed cooldowns (5s, 8s, 15s)
/// but the robot sends stale data indefinitely, so any timer eventually
/// expires and the mode reverts. The only correct fix: don't let external
/// events override user mode selections. Period.
class ModeStateNotifier extends StateNotifier<ModeState> {
  final Ref _ref;
  Timer? _timeoutTimer;
  Timer? _errorDismissTimer;
  StreamSubscription? _wsSubscription;

  static const Duration _confirmationTimeout = Duration(seconds: 10);

  /// The mode the user explicitly selected. While set, ALL external mode
  /// updates that don't match this mode are rejected. Cleared only when:
  /// - User clicks a different mode (replaced with new selection)
  /// - Mission starts (mission overrides user selection)
  /// - Provider is disposed (reconnect/restart)
  RobotMode? _userSelectedMode;

  ModeStateNotifier(this._ref) : super(const ModeState()) {
    _listenToModeEvents();
    _getInitialMode();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRUCTURED MODE LOGGING
  // ─────────────────────────────────────────────────────────────────────────

  void _logModeChange(RobotMode oldMode, RobotMode newMode, String source) {
    print('APP_MODE: ${oldMode.value} -> ${newMode.value} | source=$source');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD 50v2: SOVEREIGN USER MODE GUARD
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the incoming mode should be BLOCKED.
  /// When user has selected a mode, ONLY that mode (or mission locks) pass.
  bool _shouldBlockExternalMode(RobotMode incomingMode, {bool isLocked = false}) {
    // Mission locks are always authoritative — robot is running a mission
    if (isLocked) return false;

    // No user selection active — allow everything (initial state, pre-first-click)
    if (_userSelectedMode == null) return false;

    // Incoming mode matches user selection — allow (confirms the change)
    if (incomingMode == _userSelectedMode) return false;

    // Block: stale external data trying to override user's mode choice
    print('Mode: BLOCKED ${incomingMode.value} (user selected: ${_userSelectedMode!.value})');
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Get initial mode from telemetry (only on startup, before user interacts)
  void _getInitialMode() {
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

  /// Listen to WebSocket events for mode confirmations
  void _listenToModeEvents() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen((event) {
      if (event.type == 'mode') {
        final mode = event.data['mode'] as String?;
        if (mode != null) {
          _handleModeConfirmation(mode);
        }
      } else if (event.type == 'mode_changed') {
        _handleModeChangedEvent(event.data);
      } else if (event.type == 'status_update' ||
                 event.type == 'battery' ||
                 event.type == 'telemetry') {
        final mode = event.data['mode'] as String?;
        if (mode != null) {
          _handleModeConfirmation(mode);
        }
      } else if (event.type == 'mission_progress') {
        _handleMissionProgress(event.data);
      } else if (event.type == 'mission_complete' || event.type == 'mission_stopped') {
        _handleMissionEnded();
      }
    });
  }

  /// Handle mode_changed events (explicit mode change broadcasts from robot)
  void _handleModeChangedEvent(Map<String, dynamic> data) {
    final mode = data['mode'] as String?;
    final locked = data['locked'] as bool? ?? false;
    final lockReason = data['lock_reason'] as String?;

    print('Mode: mode_changed event - mode=$mode, locked=$locked, reason=$lockReason');

    if (mode == null) return;

    final confirmedMode = RobotMode.tryFromString(mode);
    if (confirmedMode == null) return; // Don't default to idle for unrecognized strings

    // Sovereign guard
    if (_shouldBlockExternalMode(confirmedMode, isLocked: locked)) return;

    _cancelTimeout();

    // Extract mission name from lock reason if available
    String? missionName;
    if (locked && lockReason != null && lockReason.contains(':')) {
      missionName = lockReason.split(':').last.trim();
    }

    if (state.isChanging && state.pendingMode == confirmedMode) {
      _logModeChange(state.currentMode, confirmedMode, 'ws_confirmed');
    } else {
      _logModeChange(state.currentMode, confirmedMode, 'ws_mode_changed');
    }

    state = state.copyWith(
      currentMode: confirmedMode,
      isChanging: false,
      clearPending: true,
      clearError: true,
      isModeLocked: locked,
      activeMissionName: locked ? missionName : null,
    );
  }

  /// Handle mode confirmation from status_update/battery/telemetry/mode events
  void _handleModeConfirmation(String modeValue) {
    final confirmedMode = RobotMode.tryFromString(modeValue);
    if (confirmedMode == null) return; // Don't default to idle for unrecognized strings

    // Sovereign guard
    if (_shouldBlockExternalMode(confirmedMode)) return;

    if (state.isChanging && state.pendingMode != null) {
      if (confirmedMode == state.pendingMode) {
        // Confirmed our pending mode
        _logModeChange(state.currentMode, confirmedMode, 'ws_confirmed');
        _cancelTimeout();
        state = state.copyWith(
          currentMode: confirmedMode,
          isChanging: false,
          clearPending: true,
          clearError: true,
        );
      }
      // Non-matching modes are blocked by the guard above
    } else if (!state.isChanging) {
      // Not waiting for confirmation — update if different
      // (only reachable if _userSelectedMode is null or matches)
      if (confirmedMode != state.currentMode) {
        _logModeChange(state.currentMode, confirmedMode, 'ws_external');
        state = state.copyWith(currentMode: confirmedMode);
      }
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

    print('Mode: mission_progress action=$action, mission=$missionName');

    switch (action) {
      case 'started':
        // Mission started — authoritative, overrides user selection
        _logModeChange(state.currentMode, RobotMode.mission, 'mission_started');
        _userSelectedMode = null; // Clear user selection — mission takes over
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
            print('Mode: Updating mission info for active mission');
            state = state.copyWith(
              activeMissionId: missionId,
              activeMissionName: missionName,
            );
          }
        }
        break;
    }
  }

  /// Handle mission ended (completed or stopped)
  /// v1.3: Restores previous portrait mode instead of defaulting to idle
  void _handleMissionEnded() {
    final restoreMode = state.previousPortraitMode;
    _logModeChange(state.currentMode, restoreMode, 'mission_ended');
    _userSelectedMode = restoreMode; // Protect restored mode
    state = state.copyWith(
      currentMode: restoreMode,
      isModeLocked: false,
      clearMission: true,
      isChanging: false,
      clearPending: true,
    );
    // Send the restored mode to robot
    _ref.read(websocketClientProvider).sendModeCommand(restoreMode.value, source: 'mission_end');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER-INITIATED MODE CHANGE
  // ─────────────────────────────────────────────────────────────────────────

  /// Set mode with optimistic update (v1.3: includes source context)
  Future<void> setMode(RobotMode mode, {String source = 'dropdown'}) async {
    if (!_ref.read(connectionProvider).isConnected) {
      state = state.copyWith(
        error: 'Not connected to robot',
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      return;
    }

    // Don't change if mode is locked (mission active)
    if (state.isModeLocked && mode != RobotMode.mission) {
      print('Mode: Cannot change to ${mode.value} - mode locked (mission: ${state.activeMissionName})');
      state = state.copyWith(
        error: 'Cannot change mode while mission is active',
        errorTime: DateTime.now(),
      );
      _scheduleErrorDismiss();
      return;
    }

    // Don't change if already in this mode
    if (state.currentMode == mode && !state.isChanging) {
      print('Mode: Already in ${mode.value}, skipping');
      return;
    }

    _cancelTimeout();

    print('Mode: Setting to ${mode.value} (optimistic, source=$source)');

    // Build 50v2: User selection is sovereign — persists until user clicks different mode
    _userSelectedMode = mode;

    // Optimistic update - immediately show new mode in UI
    state = state.copyWith(
      pendingMode: mode,
      isChanging: true,
      clearError: true,
    );

    // Send command to robot (v1.3: includes source)
    _ref.read(websocketClientProvider).sendModeCommand(mode.value, source: source);

    // Start confirmation timeout
    _timeoutTimer = Timer(_confirmationTimeout, _onTimeout);
  }

  /// v1.3: Store current portrait mode before entering landscape/mission
  void storePortraitMode() {
    final current = state.currentMode;
    // Only store portrait-valid modes
    final toStore = (current == RobotMode.idle ||
        current == RobotMode.silentGuardian ||
        current == RobotMode.coach)
        ? current
        : RobotMode.idle;
    print('Mode: Storing portrait mode: ${toStore.value}');
    state = state.copyWith(previousPortraitMode: toStore);
  }

  /// v1.3: Restore previous portrait mode when exiting landscape/mission
  Future<void> restorePortraitMode({String source = 'drive_exit_restore'}) async {
    final restoreMode = state.previousPortraitMode;
    print('Mode: Restoring portrait mode: ${restoreMode.value} (source=$source)');
    await setMode(restoreMode, source: source);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIMEOUT HANDLING
  // ─────────────────────────────────────────────────────────────────────────

  /// Handle timeout — no confirmation received.
  /// Trust the user's command. The sovereign guard will protect it indefinitely.
  void _onTimeout() {
    if (!state.isChanging) return;

    if (state.pendingMode != null) {
      _logModeChange(state.currentMode, state.pendingMode!, 'timeout_accepted');
      state = state.copyWith(
        currentMode: state.pendingMode!,
        isChanging: false,
        clearPending: true,
        clearError: true,
      );
      return;
    }

    // Fallback: no pending mode (shouldn't happen)
    state = state.copyWith(
      isChanging: false,
      clearPending: true,
    );
  }

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
  Future<void> setModeByString(String modeValue, {String source = 'dropdown'}) async {
    final mode = RobotMode.tryFromString(modeValue);
    if (mode == null) return; // Ignore unrecognized mode strings
    await setMode(mode, source: source);
  }

  /// Set to manual mode (v1.3: accepts source)
  Future<void> setManualMode({String source = 'drive_enter'}) async {
    await setMode(RobotMode.manual, source: source);
  }

  /// Clear error manually
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _cancelTimeout();
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
  void setMode(RobotMode mode, {String source = 'dropdown'}) {
    _ref.read(modeStateProvider.notifier).setMode(mode, source: source);
  }

  /// Set mode by string value
  void setModeByString(String modeValue, {String source = 'dropdown'}) {
    _ref.read(modeStateProvider.notifier).setModeByString(modeValue, source: source);
  }

  /// Set to manual mode (default on connect)
  void setManualMode({String source = 'drive_enter'}) {
    _ref.read(modeStateProvider.notifier).setManualMode(source: source);
  }
}
