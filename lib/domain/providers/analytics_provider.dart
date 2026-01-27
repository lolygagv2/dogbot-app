import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
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

  const AnalyticsData({
    required this.dogId,
    required this.range,
    this.treatCount = 0,
    this.detectionCount = 0,
    this.missionsAttempted = 0,
    this.missionsSucceeded = 0,
    this.activeMinutes = 0,
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
    // Only update today's stats in real-time
    switch (event.type) {
      case 'treat':
        state = AnalyticsData(
          dogId: _dogId,
          range: state.range,
          treatCount: state.treatCount + 1,
          detectionCount: state.detectionCount,
          missionsAttempted: state.missionsAttempted,
          missionsSucceeded: state.missionsSucceeded,
          activeMinutes: state.activeMinutes,
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
        );
        break;
    }
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
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
