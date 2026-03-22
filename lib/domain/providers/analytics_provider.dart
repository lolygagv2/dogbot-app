import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/dog_profile.dart';
import 'dog_profiles_provider.dart';

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
    switch (event.type) {
      // Relay sends metrics_sync on connect with the day's totals per dog
      case 'metrics_sync':
        final dogId = event.data['dog_id'] as String?;
        final metrics = event.data['metrics'] as Map<String, dynamic>?;
        if (dogId == _dogId && metrics != null) {
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

      // Real-time incremental updates
      case 'treat':
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

  /// Update the range (reloads data from summary)
  void setRange(AnalyticsRange range) {
    // For week/lifetime we'd fetch from API; for now use multiplied mock data
    final summary = _ref.read(dogDailySummaryProvider(_dogId));
    final multiplier = range == AnalyticsRange.today
        ? 1
        : range == AnalyticsRange.week
            ? 7
            : 30;
    state = AnalyticsData(
      dogId: _dogId,
      range: range,
      treatCount: summary.treatCount * multiplier,
      detectionCount: (summary.sitCount + summary.barkCount) * multiplier,
      missionsAttempted: summary.missionCount * multiplier,
      missionsSucceeded: summary.missionSuccessCount * multiplier,
      activeMinutes: 15 * multiplier, // Estimated
      coachRewards: 3 * multiplier, // Estimated
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Tab index for the Activity screen (0=Dashboard, 1=Events)
final activityTabIndexProvider = StateProvider<int>((ref) => 0);

/// 7-day demo data for the dashboard chart, keyed by dogId
final dogWeeklyStatsProvider =
    Provider.family<List<DogDailySummary>, String>((ref, dogId) {
  final now = DateTime.now();
  final rng = Random(dogId.hashCode); // deterministic per-dog

  return List.generate(7, (i) {
    final day = now.subtract(Duration(days: 6 - i));
    // Trending upward: base values increase with i
    final treats = 3 + rng.nextInt(3) + (i ~/ 2);
    final sits = 2 + rng.nextInt(3) + (i ~/ 3);
    final barks = max(1, 12 - i - rng.nextInt(3));
    final missions = 1 + rng.nextInt(2);
    final missionSuccess = rng.nextDouble() > 0.3 ? missions : missions - 1;

    return DogDailySummary(
      dogId: dogId,
      date: day,
      treatCount: treats,
      sitCount: sits,
      barkCount: barks,
      missionCount: missions,
      missionSuccessCount: max(0, missionSuccess),
      goalProgress: min(1.0, 0.4 + (i * 0.08) + rng.nextDouble() * 0.1),
    );
  });
});
