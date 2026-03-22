import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/dog_profile.dart';
import '../../../data/models/notification_event.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../theme/app_theme.dart';

/// Activity dashboard — "the money slide" for investors.
/// Shows summary stats, 7-day activity chart, and recent event log.
class ActivityDashboard extends ConsumerWidget {
  final String? dogId;

  const ActivityDashboard({super.key, this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveDogId = dogId ?? ref.watch(selectedDogProvider)?.id;

    if (effectiveDogId == null) {
      return const Center(
        child: Text(
          'No dog selected',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryStatsRow(dogId: effectiveDogId),
          const SizedBox(height: 20),
          _ActivityLineChart(dogId: effectiveDogId),
          const SizedBox(height: 20),
          const _BehaviorEventLog(),
        ],
      ),
    );
  }
}

/// 4 stat cards in a row
class _SummaryStatsRow extends ConsumerWidget {
  final String dogId;

  const _SummaryStatsRow({required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dogAnalyticsProvider(dogId));

    return Row(
      children: [
        Expanded(
          child: _CompactStatCard(
            value: analytics.treatCount.toString(),
            label: 'Treats',
            icon: Icons.cookie,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: analytics.detectionCount.toString(),
            label: 'Detections',
            icon: Icons.visibility,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: '${analytics.missionsSucceeded}/${analytics.missionsAttempted}',
            label: 'Missions',
            icon: Icons.flag,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: '${analytics.activeMinutes}m',
            label: 'Active',
            icon: Icons.timer,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _CompactStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 7-day activity score line chart
class _ActivityLineChart extends ConsumerWidget {
  final String dogId;

  const _ActivityLineChart({required this.dogId});

  double _activityScore(DogDailySummary s) {
    return min(
      100,
      (s.sitCount * 15) +
          (s.treatCount * 5) +
          (s.missionSuccessCount * 20) -
          (s.barkCount * 3).toDouble(),
    ).clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStats = ref.watch(dogWeeklyStatsProvider(dogId));
    final spots = weekStats
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), _activityScore(e.value)))
        .toList();

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Align labels to the actual days of the week
    final now = DateTime.now();
    final labels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return dayLabels[day.weekday - 1];
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Score (7 days)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.glassBorder,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 25,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[idx],
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppTheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: AppTheme.primary,
                      strokeWidth: 1,
                      strokeColor: AppTheme.background,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${s.y.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Recent behavior event log
class _BehaviorEventLog extends ConsumerWidget {
  const _BehaviorEventLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(notificationsProvider);
    final displayEvents = events.take(50).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Events',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${displayEvents.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (displayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No events yet',
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayEvents.length,
            itemBuilder: (context, index) {
              final event = displayEvents[index];
              return _EventRow(event: event);
            },
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final NotificationEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _getEventColor(event.type);
    final icon = _getEventIcon(event.type);
    final time = _formatTime(event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => Colors.red,
      NotificationEventType.treatDispensed => AppTheme.accent,
      NotificationEventType.sit ||
      NotificationEventType.lieDown ||
      NotificationEventType.stand =>
        Colors.blue,
      NotificationEventType.missionCompleted => AppTheme.accent,
      NotificationEventType.missionStarted => AppTheme.primary,
      NotificationEventType.missionFailed => AppTheme.error,
      _ => Colors.grey,
    };
  }

  IconData _getEventIcon(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => Icons.volume_up,
      NotificationEventType.sit => Icons.pets,
      NotificationEventType.lieDown => Icons.airline_seat_flat,
      NotificationEventType.stand => Icons.accessibility_new,
      NotificationEventType.treatDispensed => Icons.cookie,
      NotificationEventType.missionStarted => Icons.play_circle,
      NotificationEventType.missionCompleted => Icons.check_circle,
      NotificationEventType.missionFailed => Icons.cancel,
      _ => Icons.circle,
    };
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }
}
