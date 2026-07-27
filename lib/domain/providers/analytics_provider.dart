import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/activity_aggregation.dart';
import '../../data/models/dog_profile.dart';
import 'dog_profiles_provider.dart';
import 'notifications_provider.dart';

/// Analytics time range
enum AnalyticsRange { today, week, lifetime }

/// Provider for the selected analytics range
final analyticsRangeProvider = StateProvider<AnalyticsRange>((ref) {
  return AnalyticsRange.today;
});

/// Aggregated analytics data for a dog
class AnalyticsData {
  final String dogId;
  final AnalyticsRange range;
  final int treatCount;
  final int detectionCount;
  final int missionsAttempted;
  final int missionsSucceeded;
  final int activeMinutes;
  final int coachRewards;

  const AnalyticsData({
    required this.dogId,
    required this.range,
    this.treatCount = 0,
    this.detectionCount = 0,
    this.missionsAttempted = 0,
    this.missionsSucceeded = 0,
    this.activeMinutes = 0,
    this.coachRewards = 0,
  });

  double get successRate =>
      missionsAttempted > 0 ? missionsSucceeded / missionsAttempted : 0.0;
}

/// Provider for dog analytics, keyed on dogId
/// Merges stored summary data with real-time WebSocket events for today
final dogAnalyticsProvider =
    StateNotifierProvider.family<DogAnalyticsNotifier, AnalyticsData, String>(
        (ref, dogId) {
  return DogAnalyticsNotifier(ref, dogId);
});

class DogAnalyticsNotifier extends StateNotifier<AnalyticsData> {
  final Ref _ref;
  final String _dogId;
  StreamSubscription? _wsSubscription;

  DogAnalyticsNotifier(this._ref, this._dogId)
      : super(AnalyticsData(dogId: _dogId, range: AnalyticsRange.today)) {
    _init();
    _listenToWebSocket();
  }

  void _init() {
    // Seed from the existing daily summary provider
    final summary = _ref.read(dogDailySummaryProvider(_dogId));
    state = AnalyticsData(
      dogId: _dogId,
      range: _ref.read(analyticsRangeProvider),
      treatCount: summary.treatCount,
      detectionCount: summary.sitCount + summary.barkCount,
      missionsAttempted: summary.missionCount,
      missionsSucceeded: summary.missionSuccessCount,
      activeMinutes: 0,
    );
  }

  void _listenToWebSocket() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    // C4: filter strictly by event-source dog_id, not the selected dog. The
    // robot now tags every event with the dog_id of whichever ArUco it
    // actually saw (Workstream C). Legacy events without dog_id are skipped
    // for per-dog providers — see allDogsAnalyticsProvider for aggregates.
    final eventDogId = event.data['dog_id'] as String?;

    switch (event.type) {
      // Relay sends metrics_sync on connect with the day's totals per dog
      case 'metrics_sync':
        final metrics = event.data['metrics'] as Map<String, dynamic>?;
        if (eventDogId == _dogId && metrics != null) {
          state = AnalyticsData(
            dogId: _dogId,
            range: state.range,
            treatCount: metrics['treat_count'] as int? ?? 0,
            detectionCount: metrics['detection_count'] as int? ?? 0,
            missionsAttempted: metrics['mission_attempts'] as int? ?? 0,
            missionsSucceeded: metrics['mission_successes'] as int? ?? 0,
            activeMinutes: metrics['session_minutes'] as int? ?? 0,
            coachRewards: metrics['coach_rewards'] as int? ?? 0,
          );
        }
        break;

      // Real-time incremental updates — only attribute when we have a positive
      // match on event.data['dog_id'].
      case 'treat':
        if (eventDogId != _dogId) break;
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount + 1,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'detection':
        if (eventDogId != _dogId) break;
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount + 1,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'coach_reward':
        if (eventDogId != _dogId) break;
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards + 1,
        );
        break;
      case 'mission_complete':
        if (eventDogId != _dogId) break;
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted + 1,
          missionsSucceeded: state.missionsSucceeded + 1,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'mission_stopped':
        if (eventDogId != _dogId) break;
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted + 1,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
    }
  }

  /// Clear state (used on logout)
  void clearState() {
    state = AnalyticsData(dogId: _dogId, range: AnalyticsRange.today);
  }

  /// Update the range. Build 125: REAL data — no multiplied mock. today = the
  /// real daily summary; week = sum of the real 7-day stats; lifetime =
  /// best-effort aggregate of all available history (bounded by the relay's
  /// 7-day window the app currently holds).
  void setRange(AnalyticsRange range) {
    final events = _ref.read(notificationsProvider);
    switch (range) {
      case AnalyticsRange.today:
        final s = summarizeDay(events, dogId: _dogId, day: DateTime.now());
        state = AnalyticsData(
          dogId: _dogId,
          range: range,
          treatCount: s.treatCount,
          detectionCount: s.sitCount + s.barkCount,
          missionsAttempted: s.missionCount,
          missionsSucceeded: s.missionSuccessCount,
        );
        break;
      case AnalyticsRange.week:
        final week = summarizeWeek(events, dogId: _dogId);
        state = AnalyticsData(
          dogId: _dogId,
          range: range,
          treatCount: week.fold(0, (a, s) => a + s.treatCount),
          detectionCount: week.fold(0, (a, s) => a + s.sitCount + s.barkCount),
          missionsAttempted: week.fold(0, (a, s) => a + s.missionCount),
          missionsSucceeded: week.fold(0, (a, s) => a + s.missionSuccessCount),
        );
        break;
      case AnalyticsRange.lifetime:
        final s = summarizeAll(events, dogId: _dogId);
        state = AnalyticsData(
          dogId: _dogId,
          range: range,
          treatCount: s.treatCount,
          detectionCount: s.sitCount + s.barkCount,
          missionsAttempted: s.missionCount,
          missionsSucceeded: s.missionSuccessCount,
        );
        break;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Tab index for the Activity screen (0=Dashboard, 1=Events)
final activityTabIndexProvider = StateProvider<int>((ref) => 0);

/// C4: Aggregate analytics across all dogs (and untagged events). Counts
/// every event regardless of dog_id, so it's the right choice for the
/// "All Dogs" lens / fleet-level dashboards.
final allDogsAnalyticsProvider =
    StateNotifierProvider<AllDogsAnalyticsNotifier, AnalyticsData>((ref) {
  return AllDogsAnalyticsNotifier(ref);
});

class AllDogsAnalyticsNotifier extends StateNotifier<AnalyticsData> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  AllDogsAnalyticsNotifier(this._ref)
      : super(const AnalyticsData(dogId: '', range: AnalyticsRange.today)) {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'treat':
        state = AnalyticsData(
          dogId: state.dogId,
          range: state.range,
          treatCount: state.treatCount + 1,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'detection':
        state = AnalyticsData(
          dogId: state.dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount + 1,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'coach_reward':
        state = AnalyticsData(
          dogId: state.dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards + 1,
        );
        break;
      case 'mission_complete':
        state = AnalyticsData(
          dogId: state.dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted + 1,
          missionsSucceeded: state.missionsSucceeded + 1,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
      case 'mission_stopped':
        state = AnalyticsData(
          dogId: state.dogId,
          range: state.range,
          treatCount: state.treatCount,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted + 1,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
          coachRewards: state.coachRewards,
        );
        break;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// 7-day stats for the dashboard chart, keyed by dogId.
/// Build 125: REAL data, aggregated from the activity history — no more
/// `Random()` upward-trending fake chart.
/// Build 142: includeUntagged — a strict per-dog filter rendered the chart
/// empty despite delivered bark/guardian/treat events. Untagged events count
/// here; strict per-dog stat providers keep the C4 rule.
/// Build 147: row-level dog_id is live relay-side (2026-07-26), but events
/// stay untagged whenever the robot can't identify the dog (no ArUco in
/// frame) — any-mode dog_id stamping is still owed robot-side per the
/// 2026-07-13 attribution contract. Revisit dropping this once that ships.
final dogWeeklyStatsProvider =
    Provider.family<List<DogDailySummary>, String>((ref, dogId) {
  final events = ref.watch(notificationsProvider);
  return summarizeWeek(events, dogId: dogId, includeUntagged: true);
});
