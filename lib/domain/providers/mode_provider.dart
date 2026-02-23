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
///
/// Build 50: Complete rewrite of mode protection. Previous builds (36-49) added
/// patchwork cooldowns to individual handlers, but stale events kept finding
/// unprotected paths. Now uses a SINGLE unified guard: when the user clicks a
/// mode, ALL external mode overrides are blocked for 15 seconds. Only the
/// target mode (or mission locks) can break through.
class ModeStateNotifier extends StateNotifier<ModeState> {
  final Ref _ref;
  Timer? _timeoutTimer;
  Timer? _errorDismissTimer;
  Timer? _telemetrySyncTimer;
  StreamSubscription? _wsSubscription;

  static const Duration _confirmationTimeout = Duration(seconds: 10);

  /// Build 50: Single unified block duration. When user clicks a mode, ALL
  /// external mode updates that don't match the target are blocked for this
  /// duration. Covers: battery events, status_update, mode_changed, telemetry
  /// sync — every possible path.
  static const Duration _externalBlockDuration = Duration(seconds: 15);
  DateTime? _externalBlockUntil;

  ModeStateNotifier(this._ref) : super(const ModeState()) {
    _listenToModeEvents();
    _getInitialMode();
    _startTelemetrySync();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD 50: UNIFIED EXTERNAL MODE GUARD
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the incoming mode should be BLOCKED.
  /// Called by every handler that can change currentMode from external events.
  ///
  /// During the block window:
  /// - Target mode (pending or current) passes through → confirms the change
  /// - Mission locks (locked=true) pass through → authoritative override
  /// - Everything else is blocked → stale battery/status/mode_changed events
  bool _shouldBlockExternalMode(RobotMode incomingMode, {bool isLocked = false}) {
    // Mission locks are always authoritative
    if (isLocked) return false;

    // No block active — allow everything
    if (_externalBlockUntil == null) return false;

    // Block expired — resume normal behavior
    if (DateTime.now().isAfter(_externalBlockUntil!)) {
      print('Mode: External block expired, resuming normal sync');
      _externalBlockUntil = null;
      return false;
    }

    // During block: only accept the mode we're targeting
    final targetMode = state.pendingMode ?? state.currentMode;
    if (incomingMode == targetMode) return false;

    // Block this update
    final remainingSec = _externalBlockUntil!.difference(DateTime.now()).inSeconds;
    print('Mode: BLOCKED ${incomingMode.value} (target: ${targetMode.value}, ${remainingSec}s remaining)');
    return true;
  }

  /// Activate the external mode block (called when user initiates a mode change)
  void _activateExternalBlock() {
    _externalBlockUntil = DateTime.now().add(_externalBlockDuration);
    print('Mode: External block activated for ${_externalBlockDuration.inSeconds}s');
  }

  /// Extend the external mode block (called after timeout-trust or confirmation)
  void _extendExternalBlock() {
    _externalBlockUntil = DateTime.now().add(_externalBlockDuration);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TELEMETRY SYNC
  // ─────────────────────────────────────────────────────────────────────────

  /// Periodically sync mode from telemetry (catches missed WebSocket events)
  void _startTelemetrySync() {
    _telemetrySyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _syncFromTelemetry();
    });
  }

  /// Sync mode from telemetry if we're not in the middle of a change
  void _syncFromTelemetry() {
    if (state.isChanging) return;

    final telemetry = _ref.read(telemetryProvider);
    if (telemetry.mode.isEmpty) return;

    final telemetryMode = RobotMode.fromString(telemetry.mode);

    // Unified guard
    if (_shouldBlockExternalMode(telemetryMode)) return;

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

    final confirmedMode = RobotMode.fromString(mode);

    // Unified guard — blocks stale mode_changed events too
    if (_shouldBlockExternalMode(confirmedMode, isLocked: locked)) return;

    _cancelTimeout();

    // Extract mission name from lock reason if available
    String? missionName;
    if (locked && lockReason != null && lockReason.contains(':')) {
      missionName = lockReason.split(':').last.trim();
    }

    // If this confirms our pending mode, extend the block to protect it
    if (state.isChanging && state.pendingMode == confirmedMode) {
      print('Mode: mode_changed confirmed ${confirmedMode.value}');
      _extendExternalBlock();
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
    final confirmedMode = RobotMode.fromString(modeValue);

    // Unified guard
    if (_shouldBlockExternalMode(confirmedMode)) return;

    if (state.isChanging && state.pendingMode != null) {
      if (confirmedMode == state.pendingMode) {
        // Confirmed our pending mode
        print('Mode: Confirmed ${confirmedMode.value}');
        _cancelTimeout();
        _extendExternalBlock();
        state = state.copyWith(
          currentMode: confirmedMode,
          isChanging: false,
          clearPending: true,
          clearError: true,
        );
      }
      // Non-matching modes during pending state are already blocked by the guard above
    } else {
      // Not waiting for confirmation - update if different
      if (confirmedMode != state.currentMode) {
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
        // Mission started - lock mode to mission (authoritative, bypasses guard)
        print('Mode: Mission started: $missionName, locking mode');
        _externalBlockUntil = null; // Clear any user block — mission overrides
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
    final wasActive = state.activeMissionName;
    final restoreMode = state.previousPortraitMode;
    print('Mode: Mission ended: $wasActive, unlocking mode, restoring to ${restoreMode.value}');
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

    // Build 50: Activate unified external block — blocks ALL stale mode overrides
    _activateExternalBlock();

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
  /// Build 49+50: Trust the user's command. No error/rejection came back, so
  /// accept the pending mode. The external block continues to protect it.
  void _onTimeout() {
    if (!state.isChanging) return;

    if (state.pendingMode != null) {
      // First check: does telemetry already confirm it?
      final telemetry = _ref.read(telemetryProvider);
      if (telemetry.mode.isNotEmpty) {
        final actualMode = RobotMode.fromString(telemetry.mode);
        if (actualMode == state.pendingMode) {
          print('Mode: Timeout but telemetry confirms ${actualMode.value}');
          _extendExternalBlock();
          state = state.copyWith(
            currentMode: actualMode,
            isChanging: false,
            clearPending: true,
            clearError: true,
          );
          return;
        }
      }

      // No telemetry confirmation, but no error either — trust the command
      print('Mode: Timeout — accepting ${state.pendingMode!.value} (no error received)');
      _extendExternalBlock();
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
    final mode = RobotMode.fromString(modeValue);
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
