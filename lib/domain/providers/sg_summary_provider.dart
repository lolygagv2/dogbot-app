import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'connection_provider.dart';

/// Robot 137a5e8 (2026-08-31): Silent Guardian session summary card state.
/// Fed by sg_summary events — both the automatic level4_escalation and the
/// response to our sg_status_pull command update the same card.

class SgSummary {
  final String action; // level4_escalation | status_pull
  final int? sessionDurationSec;
  final int totalBarks;
  final Map<String, int> barkTypes; // distress|demand|alarm|aggressive|play|unclassified
  final Map<String, double> barkTypePercentages;
  final int treatsDispensed;
  final int interventionsTriggered;
  final int? escalationLevel;
  final String? fsmState;
  final String? trend; // improving | worsening | flat
  final String? currentAction; // pre-phrased — display verbatim
  final String? headline; // pre-phrased — display verbatim
  final bool aggressiveTag;
  final bool panicActive;
  final int panicEpisodes;
  final DateTime receivedAt;

  const SgSummary({
    required this.action,
    this.sessionDurationSec,
    this.totalBarks = 0,
    this.barkTypes = const {},
    this.barkTypePercentages = const {},
    this.treatsDispensed = 0,
    this.interventionsTriggered = 0,
    this.escalationLevel,
    this.fsmState,
    this.trend,
    this.currentAction,
    this.headline,
    this.aggressiveTag = false,
    this.panicActive = false,
    this.panicEpisodes = 0,
    required this.receivedAt,
  });

  static SgSummary fromEvent(Map<String, dynamic> data) {
    Map<String, int> intMap(dynamic m) => m is Map
        ? m.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0))
        : const {};
    Map<String, double> doubleMap(dynamic m) => m is Map
        ? m.map((k, v) => MapEntry('$k', (v as num?)?.toDouble() ?? 0.0))
        : const {};
    return SgSummary(
      action: data['action'] as String? ?? 'status_pull',
      sessionDurationSec: (data['session_duration_sec'] as num?)?.toInt(),
      totalBarks: (data['total_barks'] as num?)?.toInt() ?? 0,
      barkTypes: intMap(data['bark_types']),
      barkTypePercentages: doubleMap(data['bark_type_percentages']),
      treatsDispensed: (data['treats_dispensed'] as num?)?.toInt() ?? 0,
      interventionsTriggered:
          (data['interventions_triggered'] as num?)?.toInt() ?? 0,
      escalationLevel: (data['current_escalation_level'] as num?)?.toInt(),
      fsmState: data['fsm_state'] as String?,
      trend: data['trend'] as String?,
      currentAction: data['current_action'] as String?,
      headline: data['headline'] as String?,
      aggressiveTag: data['aggressive_tag'] == true,
      panicActive: data['panic_active'] == true,
      panicEpisodes: (data['panic_episodes'] as num?)?.toInt() ?? 0,
      receivedAt: DateTime.now(),
    );
  }
}

class SgSummaryState {
  final SgSummary? summary;
  final bool pulling; // a sg_status_pull is in flight
  final String? error; // robot said SG not running (running:false + error)

  const SgSummaryState({this.summary, this.pulling = false, this.error});

  SgSummaryState copyWith({SgSummary? summary, bool? pulling, String? error}) {
    return SgSummaryState(
      summary: summary ?? this.summary,
      pulling: pulling ?? this.pulling,
      error: error,
    );
  }
}

final sgSummaryProvider =
    StateNotifierProvider<SgSummaryNotifier, SgSummaryState>((ref) {
  return SgSummaryNotifier(ref);
});

class SgSummaryNotifier extends StateNotifier<SgSummaryState> {
  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _pullTimeout;

  SgSummaryNotifier(this._ref) : super(const SgSummaryState()) {
    _sub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'sg_summary')
        .listen(_onSummary);
  }

  void _onSummary(WsEvent event) {
    _pullTimeout?.cancel();
    final data = event.data;
    // Pull while SG idle → running:false + error instead of a summary.
    if (data['running'] == false) {
      connTrace('sg-summary', 'not running: ${data['error']}');
      state = SgSummaryState(
        summary: state.summary,
        pulling: false,
        error: data['error'] as String? ?? 'Silent Guardian is not running',
      );
      return;
    }
    connTrace('sg-summary',
        '${data['action']} barks=${data['total_barks']} trend=${data['trend']}');
    state = SgSummaryState(summary: SgSummary.fromEvent(data), pulling: false);
  }

  /// Ask the robot for a live summary (renders as a card, no push).
  void pull() {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (state.pulling) return;
    connTrace('sg-summary', 'pull requested');
    _ref.read(websocketClientProvider).sendSgStatusPull();
    state = state.copyWith(pulling: true, error: null);
    // Don't spin forever if the robot predates 137a5e8 and ignores the
    // command.
    _pullTimeout?.cancel();
    _pullTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && state.pulling) {
        state = state.copyWith(
            pulling: false, error: 'No response — robot may need an update');
      }
    });
  }

  /// Drop session-scoped data (e.g. when SG mode exits).
  void clear() {
    _pullTimeout?.cancel();
    state = const SgSummaryState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pullTimeout?.cancel();
    super.dispose();
  }
}
