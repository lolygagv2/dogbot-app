import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/robot_api.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';

/// OTA robot software updates — app slice of the 2026-08-07 contract.
/// The relay slice (release storage) and robot slice (wimz-updater) may not
/// exist yet: everything here degrades to "no update available" / inert
/// until they ship.

/// Latest release manifest from the relay, or null when none exists (or the
/// relay slice isn't deployed). Refresh by invalidating the provider.
final latestReleaseProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final token = ref.watch(authTokenProvider);
  if (token == null) return null;
  return ref.read(robotApiProvider).getLatestRelease(token);
});

/// Live state of an update run, driven by robot `update_status` events:
/// {state: checking|downloading|verifying|installing|restarting|success|
///  failed|rolled_back, version, progress_pct?, error?}
///
/// Robot slice confirmed (robot commit c28ed1f, 2026-08-31): the terminal
/// success/rolled_back event is emitted by whichever process survives the
/// restart, AFTER its relay reconnect — expect up to ~90s of silence past
/// `restarting`. That's normal; don't add a short timeout here.
class OtaUpdateState {
  final String? state; // null = no update run seen this session
  final String? version;
  final int? progressPct;
  final String? error;

  const OtaUpdateState({this.state, this.version, this.progressPct, this.error});

  static const _terminal = {'success', 'failed', 'rolled_back'};
  bool get inProgress => state != null && !_terminal.contains(state);
  bool get isTerminal => state != null && _terminal.contains(state);
}

final otaUpdateProvider =
    StateNotifierProvider<OtaUpdateNotifier, OtaUpdateState>((ref) {
  return OtaUpdateNotifier(ref);
});

class OtaUpdateNotifier extends StateNotifier<OtaUpdateState> {
  final Ref _ref;
  StreamSubscription? _sub;

  OtaUpdateNotifier(this._ref) : super(const OtaUpdateState()) {
    _sub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'update_status')
        .listen(_onUpdateStatus);
  }

  void _onUpdateStatus(WsEvent event) {
    final data = event.data;
    connTrace('ota-status', '${data['state']} v=${data['version']} '
        'pct=${data['progress_pct']} err=${data['error']}');
    state = OtaUpdateState(
      state: data['state'] as String? ?? state.state,
      version: data['version'] as String? ?? state.version,
      progressPct: (data['progress_pct'] as num?)?.toInt(),
      error: data['error'] as String?,
    );
  }

  /// Ask the robot to update to [version]. Fire-and-forget; all progress
  /// (including refusals — not idle / low battery) arrives as update_status
  /// events. Sets an optimistic 'requested' state so the UI reacts at once.
  void startUpdate(String version) {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (state.inProgress) return; // one run at a time
    connTrace('ota-start', version);
    _ref.read(websocketClientProvider).sendStartUpdate(version);
    state = OtaUpdateState(state: 'requested', version: version);
  }

  /// Clear a terminal state so the card returns to idle (e.g. after the
  /// user has read a failure message).
  void dismiss() {
    if (state.isTerminal) state = const OtaUpdateState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
