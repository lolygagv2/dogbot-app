import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_data.freezed.dart';
part 'analytics_data.g.dart';

/// Daily statistics for analytics charts
@freezed
class DailyStats with _$DailyStats {
  const DailyStats._();

  const factory DailyStats({
    required DateTime date,
    @Default(0) int barkCount,
    @Default(0) int sitCount,
    @Default(0) int treatCount,
    @Default(0) int missionCount,
    @Default(0) int missionSuccessCount,
    @Default(Duration.zero) Duration totalActiveTime,
  }) = _DailyStats;

  factory DailyStats.fromJson(Map<String, dynamic> json) =>
      _$DailyStatsFromJson(json);

  /// Create from API response
  factory DailyStats.fromApiResponse(Map<String, dynamic> data) {
    return DailyStats(
      date: data['date'] != null
          ? DateTime.parse(data['date'] as String)
          : DateTime.now(),
      barkCount: data['bark_count'] as int? ?? data['barkCount'] as int? ?? 0,
      sitCount: data['sit_count'] as int? ?? data['sitCount'] as int? ?? 0,
      treatCount: data['treat_count'] as int? ?? data['treatCount'] as int? ?? 0,
      missionCount: data['mission_count'] as int? ?? data['missionCount'] as int? ?? 0,
      missionSuccessCount: data['mission_success_count'] as int? ??
          data['missionSuccessCount'] as int? ?? 0,
      totalActiveTime: Duration(
        seconds: data['total_active_seconds'] as int? ??
            data['totalActiveSeconds'] as int? ?? 0,
      ),
    );
  }

  /// Calculate mission success rate as percentage
  double get successRate =>
      missionCount > 0 ? (missionSuccessCount / missionCount) * 100 : 0.0;
}

/// Aggregated analytics data for a time period
@freezed
class AnalyticsData with _$AnalyticsData {
  const AnalyticsData._();

  const factory AnalyticsData({
    required String dogId,
    required DateTime startDate,
    required DateTime endDate,
    @Default([]) List<DailyStats> dailyStats,
    @Default({}) Map<String, int> behaviorDistribution,
    @Default({}) Map<String, double> missionSuccessRates,
  }) = _AnalyticsData;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsDataFromJson(json);

  /// Get total bark count for the period
  int get totalBarks => dailyStats.fold(0, (sum, d) => sum + d.barkCount);

  /// Get total sit count for the period
  int get totalSits => dailyStats.fold(0, (sum, d) => sum + d.sitCount);

  /// Get total treat count for the period
  int get totalTreats => dailyStats.fold(0, (sum, d) => sum + d.treatCount);

  /// Get average daily barks
  double get avgDailyBarks =>
      dailyStats.isNotEmpty ? totalBarks / dailyStats.length : 0.0;

  /// Get overall success rate
  double get overallSuccessRate {
    final totalMissions = dailyStats.fold(0, (sum, d) => sum + d.missionCount);
    final totalSuccess = dailyStats.fold(0, (sum, d) => sum + d.missionSuccessCount);
    return totalMissions > 0 ? (totalSuccess / totalMissions) * 100 : 0.0;
  }
}

/// Comparison metrics between two periods
@freezed
class PeriodComparison with _$PeriodComparison {
  const factory PeriodComparison({
    required String metric,
    required double currentValue,
    required double previousValue,
    required double changePercent,
    required bool isImprovement,
  }) = _PeriodComparison;

  factory PeriodComparison.fromJson(Map<String, dynamic> json) =>
      _$PeriodComparisonFromJson(json);

  factory PeriodComparison.calculate({
    required String metric,
    required double currentValue,
    required double previousValue,
    bool lowerIsBetter = false,
  }) {
    final change = previousValue != 0
        ? ((currentValue - previousValue) / previousValue) * 100
        : 0.0;
    final isImprovement = lowerIsBetter ? change < 0 : change > 0;

    return PeriodComparison(
      metric: metric,
      currentValue: currentValue,
      previousValue: previousValue,
      changePercent: change,
      isImprovement: isImprovement,
    );
  }
}
