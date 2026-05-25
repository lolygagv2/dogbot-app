import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/night_mode_state.dart';

/// Latest `night_mode_state` snapshot the robot has published. `null` until
/// the first heartbeat arrives after connection. The override preference is
/// the source of truth on the robot side — the app only reflects it.
final nightModeProvider =
    StateNotifierProvider<NightModeNotifier, NightModeState?>((ref) {
  return NightModeNotifier(ref);
});

/// Derived: true if the last heartbeat is older than 90 seconds (or we never
/// received one). Heartbeat cadence is 60s, so 90s gives a ~30s buffer before
/// the UI starts showing the state as "stale / offline".
final nightModeIsStaleProvider = Provider<bool>((ref) {
  final notifier = ref.watch(nightModeProvider.notifier);
  // Watch the state so this re-evaluates on every emit (including the timer-
  // driven re-emit that flips _stale).
  ref.watch(nightModeProvider);
  return notifier.isStale;
});

class NightModeNotifier extends StateNotifier<NightModeState?> {
  final Ref _ref;
  StreamSubscription<WsEvent>? _wsSubscription;
  Timer? _staleTimer;
  bool _stale = false;

  /// 60s heartbeat + 30s grace.
  static const Duration _staleAfter = Duration(seconds: 90);

  NightModeNotifier(this._ref) : super(null) {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  bool get isStale {
    if (state == null) return true;
    return _stale;
  }

  void _onWsEvent(WsEvent event) {
    if (event.type != 'night_mode_state') return;
    final parsed = NightModeState.fromJson(event.data);
    if (parsed == null) {
      print('NightMode: ignoring malformed night_mode_state: ${event.data}');
      return;
    }
    _stale = false;
    _scheduleStaleCheck();
    state = parsed;
  }

  void _scheduleStaleCheck() {
    _staleTimer?.cancel();
    _staleTimer = Timer(_staleAfter, () {
      // No heartbeat in the freshness window — re-emit to flip the UI.
      _stale = true;
      if (state != null) state = state!.copyWith();
    });
  }

  /// User changed the override on the settings panel. Sends the new value to
  /// the robot and optimistically updates local state so the UI reflects the
  /// choice immediately. The next inbound heartbeat reconciles authoritatively.
  void setOverride(NightModeOverride override) {
    _ref
        .read(websocketClientProvider)
        .sendNightModeOverride(override.wireValue);
    if (state != null) {
      state = state!.copyWith(override: override);
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _staleTimer?.cancel();
    super.dispose();
  }
}
