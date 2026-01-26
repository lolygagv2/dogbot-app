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

  const ModeState({
    this.currentMode = RobotMode.idle,
    this.pendingMode,
    this.isChanging = false,
    this.error,
    this.errorTime,
  });

  ModeState copyWith({
    RobotMode? currentMode,
    RobotMode? pendingMode,
    bool? isChanging,
    String? error,
    DateTime? errorTime,
    bool clearPending = false,
    bool clearError = false,
  }) {
    return ModeState(
      currentMode: currentMode ?? this.currentMode,
      pendingMode: clearPending ? null : (pendingMode ?? this.pendingMode),
      isChanging: isChanging ?? this.isChanging,
      error: clearError ? null : (error ?? this.error),
      errorTime: clearError ? null : (errorTime ?? this.errorTime),
    );
  }

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
  StreamSubscription? _wsSubscription;
  static const Duration _confirmationTimeout = Duration(seconds: 10);

  ModeStateNotifier(this._ref) : super(const ModeState()) {
    _listenToModeEvents();
    _getInitialMode();
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
      } else if (event.type == 'status_update' ||
                 event.type == 'battery' ||
                 event.type == 'telemetry') {
        // These events may contain mode field
        final mode = event.data['mode'] as String?;
        if (mode != null) {
          _handleModeConfirmation(mode);
        }
      }
    });
  }

  /// Handle mode confirmation from telemetry/status_update
  void _handleModeConfirmation(String modeValue) {
    final confirmedMode = RobotMode.fromString(modeValue);
    print('Mode: Received confirmation - mode=$modeValue, pending=${state.pendingMode?.value}');

    // If we're waiting for a pending mode and this matches, confirm it
    if (state.isChanging && state.pendingMode != null) {
      if (confirmedMode == state.pendingMode) {
        // Success! Mode confirmed
        print('Mode: Confirmed ${confirmedMode.value}');
        _cancelTimeout();
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
      // Not waiting for confirmation - just update current mode
      state = state.copyWith(currentMode: confirmedMode);
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

    // Don't change if already in this mode
    if (state.currentMode == mode && !state.isChanging) {
      print('Mode: Already in ${mode.value}, skipping');
      return;
    }

    // Cancel any existing timeout
    _cancelTimeout();

    print('Mode: Setting to ${mode.value} (optimistic)');

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
