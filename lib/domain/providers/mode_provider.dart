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

  const ModeState({
    this.currentMode = RobotMode.idle,
    this.pendingMode,
    this.isChanging = false,
    this.error,
    this.errorTime,
    this.activeMissionId,
    this.activeMissionName,
    this.isModeLocked = false,
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
    );
  }

  /// True if a mission is currently active
  bool get isMissionActive => activeMissionId != null;

  /// Check if mode change is allowed
  bool canChangeMode() => !isModeLocked;

  /// The mode to display in UI (optimistic - shows pending if changing)
  RobotMode get displayMode => pendingMode ?? currentMode;

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
class ModeStateNotifier extends StateNotifier<ModeState> {
  final Ref _ref;
  Timer? _timeoutTimer;
  Timer? _errorDismissTimer;
  Timer? _telemetrySyncTimer;
  StreamSubscription? _wsSubscription;
  static const Duration _confirmationTimeout = Duration(seconds: 10);
  // Build 34: Debounce mode changes to prevent rapid flipping
  static const Duration _modeChangeDebounce = Duration(milliseconds: 500);
  // Build 36: User-initiated change cooldown - blocks ALL external mode updates
  static const Duration _userChangeCooldown = Duration(seconds: 2);
  DateTime? _lastModeChangeTime;
  DateTime? _userInitiatedChangeTime; // When user explicitly clicked a mode

  ModeStateNotifier(this._ref) : super(const ModeState()) {
    _listenToModeEvents();
    _getInitialMode();
    _startTelemetrySync();
  }

  /// Periodically sync mode from telemetry (catches missed WebSocket events)
  void _startTelemetrySync() {
    _telemetrySyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _syncFromTelemetry();
    });
  }

  /// Sync mode from telemetry if we're not in the middle of a change
  void _syncFromTelemetry() {
    if (state.isChanging) return; // Don't override during pending change

    // Build 36: Don't override during user-initiated change cooldown
    if (_userInitiatedChangeTime != null) {
      final timeSinceUserChange = DateTime.now().difference(_userInitiatedChangeTime!);
      if (timeSinceUserChange < _userChangeCooldown) {
        return; // User just clicked, don't sync from telemetry yet
      }
    }

    final telemetry = _ref.read(telemetryProvider);
    if (telemetry.mode.isEmpty) return;

    final telemetryMode = RobotMode.fromString(telemetry.mode);
    if (telemetryMode != state.currentMode) {
      print('Mode: Syncing from telemetry - ${telemetry.mode} (was ${state.currentMode.value})');
      state = state.copyWith(currentMode: telemetryMode);
    }
  }

  /// Get initial mode from telemetry
  void _getInitialMode() {
    final telemetry = _ref.read(telemetryProvider);
    if (telemetry.mode.isNotEmpty && telemetry.mode != 'idle') {
      state = state.copyWith(currentMode: RobotMode.fromString(telemetry.mode));
    }
  }

  /// Listen to WebSocket events for mode confirmations
  void _listenToModeEvents() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen((event) {
      // Handle mode-related events
      if (event.type == 'mode') {
        final mode = event.data['mode'] as String?;
        if (mode != null) {
          _handleModeConfirmation(mode);
        }
      } else if (event.type == 'mode_changed') {
        // Build 31: mode_changed event with locked state
        _handleModeChangedEvent(event.data);
      } else if (event.type == 'status_update' ||
                 event.type == 'battery' ||
                 event.type == 'telemetry') {
        // These events may contain mode field
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

  /// Handle Build 31 mode_changed events
  void _handleModeChangedEvent(Map<String, dynamic> data) {
    final mode = data['mode'] as String?;
    final locked = data['locked'] as bool? ?? false;
    final lockReason = data['lock_reason'] as String?;

    print('Mode: mode_changed event - mode=$mode, locked=$locked, reason=$lockReason');

    if (mode != null) {
      final confirmedMode = RobotMode.fromString(mode);
      _cancelTimeout();
      _lastModeChangeTime = DateTime.now();

      // Extract mission name from lock reason if available
      String? missionName;
      if (locked && lockReason != null && lockReason.contains(':')) {
        missionName = lockReason.split(':').last.trim();
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
  }

  /// Handle mission_progress events to lock/unlock mode
  void _handleMissionProgress(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final missionId = data['mission_id']?.toString() ?? data['id']?.toString();
    final missionName = data['mission'] as String? ?? data['mission_name'] as String? ?? missionId;

    print('Mode: mission_progress action=$action, mission=$missionName');

    switch (action) {
      case 'started':
        // Mission started - lock mode to mission
        print('Mode: Mission started: $missionName, locking mode');
        _lastModeChangeTime = DateTime.now();
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
      // For progress updates (no action field), don't change mode state
      default:
        // Build 36: Only update mission info if we're ALREADY in mission mode (confirmed by robot)
        // Don't force mode change on progress events without 'started' action
        // This prevents app showing "mission" when robot hasn't confirmed mode change
        if (state.currentMode == RobotMode.mission && missionId != null) {
          // Already in mission mode, just update mission info if needed
          if (state.activeMissionId != missionId) {
            print('Mode: Updating mission info for active mission');
            state = state.copyWith(
              activeMissionId: missionId,
              activeMissionName: missionName,
            );
          }
        }
        // Note: Don't force mission mode here - wait for explicit 'started' action
        break;
    }
  }

  /// Handle mission ended (completed or stopped)
  void _handleMissionEnded() {
    final wasActive = state.activeMissionName;
    print('Mode: Mission ended: $wasActive, unlocking mode');
    _lastModeChangeTime = DateTime.now();
    state = state.copyWith(
      currentMode: RobotMode.idle,
      isModeLocked: false,
      clearMission: true,
      isChanging: false,
      clearPending: true,
    );
  }

  /// Handle mode confirmation from telemetry/status_update
  void _handleModeConfirmation(String modeValue) {
    final confirmedMode = RobotMode.fromString(modeValue);
    print('Mode: Received confirmation - mode=$modeValue, pending=${state.pendingMode?.value}');

    // Build 36: If user just initiated a change, only accept the expected mode (or wait for timeout)
    if (_userInitiatedChangeTime != null && state.isChanging) {
      final timeSinceUserChange = DateTime.now().difference(_userInitiatedChangeTime!);
      if (timeSinceUserChange < _userChangeCooldown) {
        // During cooldown, only accept the mode we're waiting for
        if (state.pendingMode != null && confirmedMode == state.pendingMode) {
          print('Mode: Confirmed user-requested ${confirmedMode.value}');
          _cancelTimeout();
          _lastModeChangeTime = DateTime.now();
          state = state.copyWith(
            currentMode: confirmedMode,
            isChanging: false,
            clearPending: true,
            clearError: true,
          );
        } else {
          print('Mode: Ignoring ${confirmedMode.value} during user cooldown (waiting for ${state.pendingMode?.value})');
        }
        return;
      }
    }

    // Build 34: Debounce rapid mode changes (unless we're waiting for a pending change)
    if (!state.isChanging && _lastModeChangeTime != null) {
      final timeSinceLastChange = DateTime.now().difference(_lastModeChangeTime!);
      if (timeSinceLastChange < _modeChangeDebounce) {
        print('Mode: Ignoring rapid change (${timeSinceLastChange.inMilliseconds}ms < ${_modeChangeDebounce.inMilliseconds}ms)');
        return;
      }
    }

    // If we're waiting for a pending mode and this matches, confirm it
    if (state.isChanging && state.pendingMode != null) {
      if (confirmedMode == state.pendingMode) {
        // Success! Mode confirmed
        print('Mode: Confirmed ${confirmedMode.value}');
        _cancelTimeout();
        _lastModeChangeTime = DateTime.now();
        state = state.copyWith(
          currentMode: confirmedMode,
          isChanging: false,
          clearPending: true,
          clearError: true,
        );
      } else {
        // Received different mode - robot might have overridden our request
        print('Mode: Received ${confirmedMode.value} but expected ${state.pendingMode!.value}');
        // Update to what robot actually is in
        _cancelTimeout();
        _lastModeChangeTime = DateTime.now();
        state = state.copyWith(
          currentMode: confirmedMode,
          isChanging: false,
          clearPending: true,
          error: 'Mode changed to ${confirmedMode.label} instead',
          errorTime: DateTime.now(),
        );
        _scheduleErrorDismiss();
      }
    } else {
      // Not waiting for confirmation - just update current mode if different
      if (confirmedMode != state.currentMode) {
        _lastModeChangeTime = DateTime.now();
        state = state.copyWith(currentMode: confirmedMode);
      }
    }
  }

  /// Set mode with optimistic update
  Future<void> setMode(RobotMode mode) async {
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

    // Cancel any existing timeout
    _cancelTimeout();

    print('Mode: Setting to ${mode.value} (optimistic, user-initiated)');

    // Build 36: Track user-initiated change to block external mode updates during cooldown
    _userInitiatedChangeTime = DateTime.now();

    // Optimistic update - immediately show new mode in UI
    state = state.copyWith(
      pendingMode: mode,
      isChanging: true,
      clearError: true,
    );

    // Send command to robot
    _ref.read(websocketClientProvider).sendModeCommand(mode.value);

    // Start confirmation timeout
    _timeoutTimer = Timer(_confirmationTimeout, _onTimeout);
  }

  /// Handle timeout - check if mode actually changed before showing error
  void _onTimeout() {
    if (!state.isChanging) return;

    // Check latest telemetry - mode may have changed without explicit confirmation event
    final telemetry = _ref.read(telemetryProvider);
    if (state.pendingMode != null && telemetry.mode.isNotEmpty) {
      final actualMode = RobotMode.fromString(telemetry.mode);
      if (actualMode == state.pendingMode) {
        // Mode actually changed, just didn't get explicit confirmation event
        print('Mode: Timeout but telemetry shows mode=${actualMode.value} — confirming');
        state = state.copyWith(
          currentMode: actualMode,
          isChanging: false,
          clearPending: true,
          clearError: true,
        );
        return;
      }
    }

    print('Mode: Timeout waiting for confirmation, reverting from ${state.pendingMode?.value} to ${state.currentMode.value}');

    state = state.copyWith(
      isChanging: false,
      clearPending: true,
      error: 'Mode change timed out',
      errorTime: DateTime.now(),
    );
    _scheduleErrorDismiss();
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
  Future<void> setModeByString(String modeValue) async {
    final mode = RobotMode.fromString(modeValue);
    await setMode(mode);
  }

  /// Set to manual mode
  Future<void> setManualMode() async {
    await setMode(RobotMode.manual);
  }

  /// Clear error manually
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _cancelTimeout();
    _errorDismissTimer?.cancel();
    _telemetrySyncTimer?.cancel();
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
  void setMode(RobotMode mode) {
    _ref.read(modeStateProvider.notifier).setMode(mode);
  }

  /// Set mode by string value
  void setModeByString(String modeValue) {
    _ref.read(modeStateProvider.notifier).setModeByString(modeValue);
  }

  /// Set to manual mode (default on connect)
  void setManualMode() {
    _ref.read(modeStateProvider.notifier).setManualMode();
  }
}
