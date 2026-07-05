import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';

/// Persisted prefs keys for Silent Guardian config.
class _SgKeys {
  // A-WORDING: user-facing copy is "intervention" now, but the prefs key
  // keeps its historical name so existing users' saved level survives.
  static const interventionLevel = 'sg_punishment_level';
}

/// Silent Guardian runtime config (app is source of truth; robot mutates in
/// memory only and reverts to YAML default on restart).
///
/// `interventionLevel` is the sustained barks-per-minute threshold for the
/// fast-escalation jump (robot bypasses the L1→L4 ladder and goes straight
/// to calming music). 0 = disabled; 10–90 = active. Lower = more aggressive.
class SilentGuardianState {
  /// 0 means Off (no fast escalation). Otherwise 10–90 BPM.
  final int interventionLevel;

  /// Last error from a sg_config command_ack, cleared on next successful ack
  /// or next user-initiated send. Surfaced as a toast by the slider widget.
  final String? lastError;

  const SilentGuardianState({
    this.interventionLevel = 0,
    this.lastError,
  });

  bool get isEnabled => interventionLevel > 0;

  SilentGuardianState copyWith({
    int? interventionLevel,
    Object? lastError = _sentinel,
  }) {
    return SilentGuardianState(
      interventionLevel: interventionLevel ?? this.interventionLevel,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  static const _sentinel = Object();
}

final silentGuardianProvider =
    StateNotifierProvider<SilentGuardianNotifier, SilentGuardianState>((ref) {
  return SilentGuardianNotifier(ref);
});

class SilentGuardianNotifier extends StateNotifier<SilentGuardianState> {
  final Ref _ref;
  SharedPreferences? _prefs;
  StreamSubscription<WsConnectionState>? _stateSub;
  StreamSubscription<WsEvent>? _eventSub;
  WsConnectionState _lastWsState = WsConnectionState.disconnected;

  SilentGuardianNotifier(this._ref) : super(const SilentGuardianState()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getInt(_SgKeys.interventionLevel) ?? 0;
    state = state.copyWith(interventionLevel: _normalize(stored));

    final ws = _ref.read(websocketClientProvider);

    // Re-send current value whenever the WS transitions into connected
    // (covers cold-open auto-connect, reconnect-after-drop, and superseded
    // → new-session paths). Robot is in-memory only; app is the truth.
    _stateSub = ws.stateStream.listen((next) {
      if (next == WsConnectionState.connected &&
          _lastWsState != WsConnectionState.connected) {
        _pushToRobot();
      }
      _lastWsState = next;
    });

    // Surface failed acks via state.lastError; clear on success.
    _eventSub = ws.eventStream.listen((event) {
      if (event.type != 'command_ack') return;
      final cmd = event.data['command'];
      if (cmd != 'sg_config') return;
      final success = event.data['success'] == true;
      if (success) {
        if (state.lastError != null) {
          state = state.copyWith(lastError: null);
        }
      } else {
        final err = event.data['error']?.toString() ?? 'Unknown error';
        state = state.copyWith(lastError: err);
      }
    });

    // If WS is already up when this notifier spins up, push immediately.
    if (ws.state == WsConnectionState.connected) {
      _lastWsState = WsConnectionState.connected;
      _pushToRobot();
    }
  }

  /// Coerce arbitrary stored ints into the allowed set: 0 (Off) or 10–90.
  int _normalize(int raw) {
    if (raw <= 0) return 0;
    if (raw < 10) return 10;
    if (raw > 90) return 90;
    return raw;
  }

  /// Update the intervention level. 0 disables; otherwise clamped to 10–90.
  Future<void> setInterventionLevel(int value) async {
    final next = _normalize(value);
    if (next == state.interventionLevel) return;
    state = state.copyWith(interventionLevel: next, lastError: null);
    await _prefs?.setInt(_SgKeys.interventionLevel, next);
    _pushToRobot();
  }

  void _pushToRobot() {
    final ws = _ref.read(websocketClientProvider);
    ws.sendSgConfig(fastEscalationBpm: state.interventionLevel);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}
