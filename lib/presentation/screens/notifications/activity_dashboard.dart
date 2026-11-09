import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/dog_profile.dart';
import '../../../data/models/notification_event.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../../l10n/l10n.dart';
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
      return Center(
        child: Text(
          context.l10n.activityNoDogSelected,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final w = context.wimz;

    return Row(
      children: [
        Expanded(
          child: _CompactStatCard(
            value: analytics.treatCount.toString(),
            label: context.l10n.activityStatTreats,
            icon: Icons.cookie,
            color: w.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: analytics.detectionCount.toString(),
            label: context.l10n.activityStatDetections,
            icon: Icons.visibility,
            color: w.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: '${analytics.missionsSucceeded}/${analytics.missionsAttempted}',
            label: context.l10n.activityStatMissions,
            icon: Icons.flag,
            color: w.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            value: analytics.coachRewards.toString(),
            label: context.l10n.activityStatCoach,
            icon: Icons.school,
            color: w.inkMuted,
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
    final w = context.wimz;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: w.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: w.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: w.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Event-type series available on the activity chart. Fixed order and fixed
/// color per type (same colors these events wear elsewhere in the app).
enum _ActivitySeries { treats, barks, behaviors, missions, alerts }

extension _ActivitySeriesSpec on _ActivitySeries {
  String label(AppLocalizations l) => switch (this) {
        _ActivitySeries.treats => l.activitySeriesTreats,
        _ActivitySeries.barks => l.activitySeriesBarks,
        _ActivitySeries.behaviors => l.activitySeriesBehaviors,
        _ActivitySeries.missions => l.activitySeriesMissions,
        _ActivitySeries.alerts => l.activitySeriesAlerts,
      };

  /// Series colour. Five labelled lines need five distinct marks, so this
  /// follows the brand differentiation palette (ink / error / ink-muted /
  /// signal / gold-deep); the legend chips and tooltips print the name.
  Color color(BuildContext context) {
    final w = context.wimz;
    return switch (this) {
      _ActivitySeries.treats => w.ink,
      _ActivitySeries.barks => Theme.of(context).colorScheme.error,
      _ActivitySeries.behaviors => w.inkMuted,
      _ActivitySeries.missions => w.signal,
      _ActivitySeries.alerts => w.goldDeep,
    };
  }

  int countOf(DogDailySummary s) => switch (this) {
        _ActivitySeries.treats => s.treatCount,
        _ActivitySeries.barks => s.barkCount,
        _ActivitySeries.behaviors => s.sitCount,
        _ActivitySeries.missions => s.missionCount,
        _ActivitySeries.alerts => s.alertCount,
      };
}

/// Visible series on the activity chart — provider scope so the toggles
/// survive tab switches. All on by default.
final activityChartSeriesProvider = StateProvider<Set<_ActivitySeries>>(
    (ref) => _ActivitySeries.values.toSet());

/// 7-day per-event-type activity chart with series toggles.
class _ActivityLineChart extends ConsumerWidget {
  final String dogId;

  const _ActivityLineChart({required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStats = ref.watch(dogWeeklyStatsProvider(dogId));
    final visible = ref.watch(activityChartSeriesProvider);
    final w = context.wimz;

    // Fixed series order; a toggled-off series never repaints the survivors.
    final activeSeries =
        _ActivitySeries.values.where(visible.contains).toList();

    var maxCount = 0;
    for (final s in activeSeries) {
      for (final day in weekStats) {
        if (s.countOf(day) > maxCount) maxCount = s.countOf(day);
      }
    }
    // Integer-friendly headroom; keep a sane floor so an empty week still
    // draws a scaled axis.
    final maxY = (maxCount < 4 ? 4 : maxCount + 1).toDouble();
    final yInterval = (maxY / 4).ceilToDouble();

    // Align labels to the actual days of the week (locale-aware short names)
    final dayFormat = DateFormat.E(Localizations.localeOf(context).toString());
    final now = DateTime.now();
    final labels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return dayFormat.format(day);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.activityChartTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: w.ink,
          ),
        ),
        const SizedBox(height: 8),
        // Series toggles — double as the chart legend.
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final s in _ActivitySeries.values)
              FilterChip(
                selected: visible.contains(s),
                showCheckmark: false,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visible.contains(s)
                        ? s.color(context)
                        : w.inkDisabled,
                  ),
                ),
                label: Text(
                  s.label(context.l10n),
                  style: TextStyle(
                    fontSize: 11,
                    color: visible.contains(s)
                        ? w.ink
                        : w.inkMuted,
                  ),
                ),
                backgroundColor: w.surfaceRaised,
                selectedColor: w.surfaceSunken,
                side: BorderSide(
                  color: visible.contains(s)
                      ? s.color(context).withValues(alpha: 0.5)
                      : w.line,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (on) {
                  final next = {...visible};
                  on ? next.add(s) : next.remove(s);
                  ref.read(activityChartSeriesProvider.notifier).state = next;
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: w.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: w.line),
          ),
          child: activeSeries.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.activityNoSeriesSelected,
                    style: TextStyle(color: w.inkMuted, fontSize: 12),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: w.line,
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: w.inkMuted,
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
                                style: TextStyle(
                                  color: w.inkMuted,
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
                      for (final s in activeSeries)
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < weekStats.length; i++)
                              FlSpot(
                                  i.toDouble(),
                                  s.countOf(weekStats[i]).toDouble()),
                          ],
                          isCurved: false,
                          color: s.color(context),
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 2.5,
                              color: s.color(context),
                              strokeWidth: 1,
                              strokeColor: w.surface,
                            ),
                          ),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            LineTooltipItem(
                              context.l10n.activitySeriesCount(activeSeries[spot.barIndex].label(context.l10n), spot.y.toInt()),
                              TextStyle(
                                color: activeSeries[spot.barIndex].color(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
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
    final w = context.wimz;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.activityRecentEvents,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: w.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: w.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${displayEvents.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: w.inkMuted,
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
                context.l10n.activityNoEvents,
                style: TextStyle(color: w.inkMuted),
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
    final w = context.wimz;
    final color = _getEventColor(context, event.type);
    final icon = _getEventIcon(event.type);
    final time = _formatTime(context, event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: w.inkMuted,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(
                color: w.inkMuted,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(BuildContext context, NotificationEventType type) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return switch (type) {
      NotificationEventType.bark => cs.error,
      NotificationEventType.treatDispensed => w.ink,
      NotificationEventType.sit ||
      NotificationEventType.lieDown ||
      NotificationEventType.stand =>
        w.ink,
      NotificationEventType.missionCompleted => w.ink,
      NotificationEventType.missionStarted => cs.primary,
      NotificationEventType.missionFailed => cs.error,
      NotificationEventType.coachReward => w.inkMuted,
      _ => w.inkMuted,
    };
  }

  IconData _getEventIcon(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => Icons.volume_up,
      NotificationEventType.sit => Icons.pets,
      NotificationEventType.lieDown => Icons.airline_seat_flat,
      NotificationEventType.stand => Icons.accessibility_new,
      NotificationEventType.treatDispensed => Icons.cookie,
      NotificationEventType.coachReward => Icons.school,
      NotificationEventType.missionStarted => Icons.play_circle,
      NotificationEventType.missionCompleted => Icons.check_circle,
      NotificationEventType.missionFailed => Icons.cancel,
      _ => Icons.circle,
    };
  }

  String _formatTime(BuildContext context, DateTime timestamp) {
    // Defensive: any UTC-parsed instant renders in device-local time.
    // Locale-aware: "Sep 4, 3:04 PM" (en) / "9월 4일 오후 3:04" (ko).
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMMd(locale).add_jm().format(timestamp.toLocal());
  }
}
