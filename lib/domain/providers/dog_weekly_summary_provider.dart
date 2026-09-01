import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'connection_provider.dart';

/// Robot 386aef0 (2026-09-01): per-dog weekly summary (Mon–Sun), pulled via
/// dog_weekly_summary_pull → answered with a dog_weekly_summary event —
/// same pull→event pattern as sg_status_pull. `headline` is pre-phrased by
/// the robot (owner_phrases yaml) — display verbatim.

class DogWeeklyBarks {
  final int total;
  final int previousWeek;
  final double? changePercent;
  final String? trend; // up | down | stable
  final Map<String, int> byType; // same groups as the SG summary card
  const DogWeeklyBarks({
    this.total = 0,
    this.previousWeek = 0,
    this.changePercent,
    this.trend,
    this.byType = const {},
  });
}

class DogWeeklyCoaching {
  final int attempts;
  final int completed;
  final double? successRate;
  final Map<String, int> byTrick;
  const DogWeeklyCoaching({
    this.attempts = 0,
    this.completed = 0,
    this.successRate,
    this.byTrick = const {},
  });
}

class DogWeeklySummary {
  final String? dogId;
  final String? dogName;
  final String? weekStart; // ISO8601 UTC from the robot
  final String? weekEnd;
  final String? headline; // pre-phrased — display verbatim
  final DogWeeklyBarks barks;
  final int treatsTotal;
  final int treatsRewards;
  final DogWeeklyCoaching coaching;
  final int guardianInterventions;
  final int guardianSuccessfulQuiets;
  final int guardianHouseholdSessions;
  final DateTime receivedAt;

  const DogWeeklySummary({
    this.dogId,
    this.dogName,
    this.weekStart,
    this.weekEnd,
    this.headline,
    this.barks = const DogWeeklyBarks(),
    this.treatsTotal = 0,
    this.treatsRewards = 0,
    this.coaching = const DogWeeklyCoaching(),
    this.guardianInterventions = 0,
    this.guardianSuccessfulQuiets = 0,
    this.guardianHouseholdSessions = 0,
    required this.receivedAt,
  });

  static DogWeeklySummary fromEvent(Map<String, dynamic> data) {
    Map<String, int> intMap(dynamic m) => m is Map
        ? m.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0))
        : const {};
    final barks = data['barks'] is Map
        ? (data['barks'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final treats = data['treats'] is Map
        ? (data['treats'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final coaching = data['coaching'] is Map
        ? (data['coaching'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final guardian = data['guardian'] is Map
        ? (data['guardian'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return DogWeeklySummary(
      dogId: data['dog_id'] as String?,
      dogName: data['dog_name'] as String?,
      weekStart: data['week_start'] as String?,
      weekEnd: data['week_end'] as String?,
      headline: data['headline'] as String?,
      barks: DogWeeklyBarks(
        total: (barks['total'] as num?)?.toInt() ?? 0,
        previousWeek: (barks['previous_week'] as num?)?.toInt() ?? 0,
        changePercent: (barks['change_percent'] as num?)?.toDouble(),
        trend: barks['trend'] as String?,
        byType: intMap(barks['by_type']),
      ),
      treatsTotal: (treats['total'] as num?)?.toInt() ?? 0,
      treatsRewards: (treats['rewards'] as num?)?.toInt() ?? 0,
      coaching: DogWeeklyCoaching(
        attempts: (coaching['attempts'] as num?)?.toInt() ?? 0,
        completed: (coaching['completed'] as num?)?.toInt() ?? 0,
        successRate: (coaching['success_rate'] as num?)?.toDouble(),
        byTrick: intMap(coaching['by_trick']),
      ),
      guardianInterventions: (guardian['interventions'] as num?)?.toInt() ?? 0,
      guardianSuccessfulQuiets:
          (guardian['successful_quiets'] as num?)?.toInt() ?? 0,
      guardianHouseholdSessions:
          (guardian['household_sessions'] as num?)?.toInt() ?? 0,
      receivedAt: DateTime.now(),
    );
  }
}

class DogWeeklySummaryState {
  final DogWeeklySummary? summary;
  final bool pulling;
  final String? error;

  const DogWeeklySummaryState({this.summary, this.pulling = false, this.error});
}

/// Family keyed on the dog's canonical UUID (profile.id).
final dogWeeklySummaryProvider = StateNotifierProvider.family<
    DogWeeklySummaryNotifier, DogWeeklySummaryState, String>((ref, dogId) {
  return DogWeeklySummaryNotifier(ref, dogId);
});

class DogWeeklySummaryNotifier extends StateNotifier<DogWeeklySummaryState> {
  final Ref _ref;
  final String _dogId;
  StreamSubscription? _sub;
  Timer? _pullTimeout;

  DogWeeklySummaryNotifier(this._ref, this._dogId)
      : super(const DogWeeklySummaryState()) {
    _sub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'dog_weekly_summary')
        .listen(_onSummary);
  }

  void _onSummary(WsEvent event) {
    final data = event.data;
    // Replies for other dogs belong to their own family instance. A reply
    // with no dog_id (e.g. the unknown_dog error flavor) goes to whichever
    // instance is waiting on a pull.
    final replyDogId = data['dog_id'] as String?;
    if (replyDogId != null && replyDogId != _dogId) return;
    if (replyDogId == null && !state.pulling) return;
    _pullTimeout?.cancel();
    final error = data['error'] as String?;
    if (error != null) {
      connTrace('dog-weekly', 'error for $_dogId: $error');
      state = DogWeeklySummaryState(
        summary: state.summary,
        pulling: false,
        error: error == 'unknown_dog'
            ? 'Robot doesn\'t know this dog yet'
            : error,
      );
      return;
    }
    connTrace('dog-weekly',
        'summary for $_dogId barks=${(data['barks'] as Map?)?['total']}');
    state = DogWeeklySummaryState(
        summary: DogWeeklySummary.fromEvent(data), pulling: false);
  }

  void pull({String? dogName}) {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (state.pulling) return;
    connTrace('dog-weekly', 'pull requested for $_dogId');
    _ref
        .read(websocketClientProvider)
        .sendDogWeeklySummaryPull(dogId: _dogId, dogName: dogName);
    state = DogWeeklySummaryState(summary: state.summary, pulling: true);
    _pullTimeout?.cancel();
    // Same guard as sg_status_pull: don't spin on a robot that predates
    // 386aef0 and ignores the command.
    _pullTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && state.pulling) {
        state = DogWeeklySummaryState(
          summary: state.summary,
          pulling: false,
          error: 'No response — robot may need an update',
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pullTimeout?.cancel();
    super.dispose();
  }
}
