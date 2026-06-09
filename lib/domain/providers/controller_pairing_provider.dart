import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/controller_info.dart';

/// Robot-hosted Xbox controller pairing.
///
/// The phone never pairs over its own Bluetooth. This notifier is a thin remote
/// for the robot's BlueZ stack: it sends `controller_*` commands over the same
/// WebSocket used for motor/servo commands (works in both cloud-relay and
/// local-AP mode — the singleton client + setTargetDevice handle both), and it
/// renders the authoritative snapshot the robot pushes back.
///
/// Additive + safe for un-updated beta robots: if no `controller_status` reply
/// arrives within [_capabilityTimeout] of the first request, we surface
/// [ControllerPhase.unsupported] and the UI shows an inert "needs firmware
/// update" state instead of breaking anything.

/// WS command names (app → robot). Kept as constants so the contract in
/// ROBOT_CONTROLLER_PAIRING_*.md has a single source of truth.
class ControllerCommands {
  ControllerCommands._();
  static const status = 'controller_status';
  static const scan = 'controller_scan';
  static const pair = 'controller_pair';
  static const trust = 'controller_trust';
  static const forget = 'controller_forget';
  static const reconnect = 'controller_reconnect';
}

/// WS event types (robot → app).
class ControllerEvents {
  ControllerEvents._();
  static const status = 'controller_status';
  static const scanResult = 'controller_scan_result';
  static const pairProgress = 'controller_pair_progress';
  static const error = 'controller_error';
}

enum ControllerPhase {
  /// Haven't heard from the robot yet (waiting on first status).
  unknown,

  /// Robot answered — we have a live snapshot.
  ready,

  /// No reply in time → old firmware / feature not on this robot.
  unsupported,
}

class ControllerPairingState {
  final ControllerPhase phase;
  final ControllerSnapshot snapshot;

  /// True while a one-shot command (pair/trust/forget/reconnect) is in flight,
  /// keyed by controller address so a row can show its own spinner.
  final String? busyAddress;

  /// Non-fatal error/progress message to surface in a snackbar or inline.
  final String? errorMessage;
  final String? progressMessage;

  const ControllerPairingState({
    this.phase = ControllerPhase.unknown,
    this.snapshot = const ControllerSnapshot(),
    this.busyAddress,
    this.errorMessage,
    this.progressMessage,
  });

  bool get scanning => snapshot.scanning;

  ControllerPairingState copyWith({
    ControllerPhase? phase,
    ControllerSnapshot? snapshot,
    String? busyAddress,
    String? errorMessage,
    String? progressMessage,
    bool clearBusy = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return ControllerPairingState(
      phase: phase ?? this.phase,
      snapshot: snapshot ?? this.snapshot,
      busyAddress: clearBusy ? null : (busyAddress ?? this.busyAddress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      progressMessage:
          clearProgress ? null : (progressMessage ?? this.progressMessage),
    );
  }
}

final controllerPairingProvider =
    StateNotifierProvider<ControllerPairingNotifier, ControllerPairingState>(
        (ref) {
  return ControllerPairingNotifier(ref);
});

class ControllerPairingNotifier extends StateNotifier<ControllerPairingState> {
  final Ref _ref;
  Timer? _capabilityTimer;

  /// How long we wait for the first snapshot before declaring the robot's
  /// firmware doesn't support this feature.
  static const _capabilityTimeout = Duration(seconds: 4);

  ControllerPairingNotifier(this._ref) : super(const ControllerPairingState());

  WebSocketClient get _ws => _ref.read(websocketClientProvider);

  /// Called when the screen opens. Subscribes to robot events and requests the
  /// current snapshot. Safe to call repeatedly.
  void start() {
    // Build 130: receive controller_* via the direct callback, not the
    // broadcast eventStream — a late screen-scoped subscriber to that stream was
    // missing the probe reply (see WebSocketClient.onControllerEvent).
    _ws.onControllerEvent = _onEvent;
    refreshStatus();
  }

  /// Ask the robot for its current controller snapshot. Arms the capability
  /// timeout only while we still haven't heard back at all.
  void refreshStatus() {
    state = state.copyWith(clearError: true);
    connTrace('ctrl-status-send', 'target=${_ws.targetDeviceId}');
    _ws.sendCommand(ControllerCommands.status);
    if (state.phase == ControllerPhase.unknown) {
      _capabilityTimer?.cancel();
      _capabilityTimer = Timer(_capabilityTimeout, () {
        if (mounted && state.phase == ControllerPhase.unknown) {
          connTrace('ctrl-status-timeout', 'no controller_status in '
              '${_capabilityTimeout.inSeconds}s → unsupported');
          state = state.copyWith(phase: ControllerPhase.unsupported);
        }
      });
    }
  }

  /// Re-probe from a hard "unsupported" state (manual Retry button). Resets the
  /// phase so the capability timer arms again.
  void retry() {
    state = state.copyWith(phase: ControllerPhase.unknown, clearError: true);
    refreshStatus();
  }

  /// Start/stop Bluetooth discovery on the robot (puts it in pairing mode).
  void setScan(bool enable) {
    if (state.phase == ControllerPhase.unsupported) return;
    _ws.sendCommand(ControllerCommands.scan, {'enable': enable});
    // Optimistic — the authoritative `scanning` flag comes back via status.
    state = state.copyWith(
      snapshot: ControllerSnapshot(
        scanning: enable,
        controllers: state.snapshot.controllers,
        activeAddress: state.snapshot.activeAddress,
      ),
      clearError: true,
    );
  }

  void pair(String address) =>
      _oneShot(ControllerCommands.pair, address, 'Pairing…');

  /// The user's sign-off: persist (or un-persist) a controller so the robot
  /// auto-reconnects it after a drop or reboot.
  void setTrusted(String address, bool trusted) => _oneShot(
        ControllerCommands.trust,
        address,
        trusted ? 'Saving…' : 'Removing trust…',
        extra: {'trusted': trusted},
      );

  void forget(String address) =>
      _oneShot(ControllerCommands.forget, address, 'Forgetting…');

  void reconnect(String address) =>
      _oneShot(ControllerCommands.reconnect, address, 'Reconnecting…');

  void _oneShot(String command, String address, String progress,
      {Map<String, dynamic>? extra}) {
    if (state.phase == ControllerPhase.unsupported) return;
    _ws.sendCommand(command, {'address': address, ...?extra});
    state = state.copyWith(
      busyAddress: address,
      progressMessage: progress,
      clearError: true,
    );
  }

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearProgress: true);

  void _onEvent(WsEvent event) {
    if (event.type.startsWith('controller_')) {
      connTrace('ctrl-evt-rx', event.type);
    }
    switch (event.type) {
      case ControllerEvents.status:
        _capabilityTimer?.cancel();
        state = state.copyWith(
          phase: ControllerPhase.ready,
          snapshot: ControllerSnapshot.fromJson(event.data),
          clearBusy: true,
          clearProgress: true,
        );
        break;

      case ControllerEvents.scanResult:
        // Discovery trickle. Merge into the current list; the next full status
        // is authoritative, this just keeps the "Found" list live mid-scan.
        final found = ControllerInfo.fromJson(event.data);
        if (found.address.isEmpty) break;
        final existing = state.snapshot.controllers;
        if (existing.any((c) => c.address == found.address)) break;
        state = state.copyWith(
          snapshot: ControllerSnapshot(
            scanning: true,
            controllers: [...existing, found],
            activeAddress: state.snapshot.activeAddress,
          ),
        );
        break;

      case ControllerEvents.pairProgress:
        final msg = event.data['message'] as String?;
        final stage = event.data['stage'] as String?;
        state = state.copyWith(
          progressMessage: msg ?? _stageLabel(stage),
        );
        break;

      case ControllerEvents.error:
        final msg = event.data['message'] as String? ??
            event.data['code'] as String? ??
            'Controller error';
        state = state.copyWith(
          errorMessage: msg,
          clearBusy: true,
          clearProgress: true,
        );
        break;
    }
  }

  String? _stageLabel(String? stage) {
    switch (stage) {
      case 'pairing':
        return 'Pairing…';
      case 'connecting':
        return 'Connecting…';
      case 'done':
        return 'Done';
    }
    return null;
  }

  @override
  void dispose() {
    _capabilityTimer?.cancel();
    if (_ws.onControllerEvent == _onEvent) _ws.onControllerEvent = null;
    super.dispose();
  }
}
