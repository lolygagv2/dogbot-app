import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/sg_summary_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Robot 137a5e8: Silent Guardian session summary card. Shown above the SG
/// event feed — renders the latest sg_summary (auto level-4 escalation or a
/// manual status pull). `headline` and `current_action` are pre-phrased by
/// the robot and displayed verbatim.
class SgSummaryCard extends ConsumerWidget {
  const SgSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sgSummaryProvider);
    final s = state.summary;
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      // Panic active: error edge — the "Panic active" tag below carries the
      // word + icon, so the edge colour never stands alone.
      decoration: WimzTheme.cardDecoration(
        context,
        radius: 12,
        borderColor: (s?.panicActive ?? false) ? cs.error : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: cs.onSurface, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.sgSessionSummary,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Pull-to-refresh the live summary
              state.pulling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                      onPressed: () =>
                          ref.read(sgSummaryProvider.notifier).pull(),
                    ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 14, color: w.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(color: w.inkMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (s == null && state.error == null) ...[
            const SizedBox(height: 4),
            Text(
              l.sgTapRefresh,
              style: TextStyle(color: w.inkMuted, fontSize: 12),
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 6),
            if (s.headline != null)
              Text(
                s.headline!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            if (s.currentAction != null) ...[
              const SizedBox(height: 2),
              Text(
                s.currentAction!,
                style: TextStyle(color: w.inkMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat(l.sgStatBarks, '${s.totalBarks}'),
                _Stat(l.sgStatTreats, '${s.treatsDispensed}'),
                _Stat(l.sgStatInterventions, '${s.interventionsTriggered}'),
                // The level number itself is the information; no hue.
                if (s.escalationLevel != null)
                  _Stat(l.sgStatLevel, '${s.escalationLevel}'),
                _TrendStat(trend: s.trend),
              ],
            ),
            if (s.barkTypePercentages.isNotEmpty) ...[
              const SizedBox(height: 8),
              _BarkTypeBar(percentages: s.barkTypePercentages),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final e in _sorted(s.barkTypePercentages))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: WimzStatus.barkType(context, e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key} ${e.value.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: w.inkMuted),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (s.barkTimeline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.sgBarkTimeline,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: w.inkMuted,
                      ),
                    ),
                  ),
                  if (s.trendDetail != null)
                    Text(
                      l.sgRateLine(
                        s.trendDetail!.recentRatePerMin.toStringAsFixed(1),
                        s.trendDetail!.sessionRatePerMin.toStringAsFixed(1),
                      ),
                      style: TextStyle(fontSize: 10, color: w.inkMuted),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _BarkTimelineChart(buckets: s.barkTimeline),
            ],
            if (s.aggressiveTag || s.panicActive || s.panicEpisodes > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (s.panicActive)
                    _Tag(l.sgPanicActive, cs.error,
                        icon: Icons.warning_amber),
                  if (!s.panicActive && s.panicEpisodes > 0)
                    _Tag(l.sgPanicEpisodes(s.panicEpisodes), w.inkMuted,
                        icon: Icons.history),
                  if (s.aggressiveTag)
                    _Tag(l.sgAggressiveBehavior, cs.error,
                        icon: Icons.report),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  static List<MapEntry<String, double>> _sorted(Map<String, double> m) {
    final entries = m.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

/// Barks over session time: one baseline-anchored bar per bark_timeline
/// bucket, stacked by type in the same fixed color order as the legend
/// above. Bar heights scale to the busiest bucket; the type legend is the
/// percentage-bar legend already on the card.
class _BarkTimelineChart extends StatelessWidget {
  final List<SgTimelineBucket> buckets;
  const _BarkTimelineChart({required this.buckets});

  static String _fmtMin(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${r}m';
  }

  @override
  Widget build(BuildContext context) {
    final maxTotal =
        buckets.fold<int>(0, (m, b) => b.total > m ? b.total : m);
    if (maxTotal == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Padding(
                    // Surface gap between adjacent bars.
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: b.total == 0
                        ? const SizedBox.shrink()
                        : FractionallySizedBox(
                            heightFactor:
                                (b.total / maxTotal).clamp(0.06, 1.0),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
                              child: Column(
                                children: [
                                  // Stack top-down in reverse fixed order so
                                  // the first legend type sits on the baseline.
                                  for (final type
                                      in WimzStatus.barkTypes.reversed)
                                    if ((b.counts[type] ?? 0) > 0)
                                      Expanded(
                                        flex: b.counts[type]!,
                                        child: Container(
                                            color: WimzStatus.barkType(
                                                context, type)),
                                      ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmtMin(buckets.first.offsetMin),
                style: TextStyle(fontSize: 9, color: context.wimz.inkMuted)),
            Text(_fmtMin(buckets.last.offsetMin),
                style: TextStyle(fontSize: 9, color: context.wimz.inkMuted)),
          ],
        ),
      ],
    );
  }
}

/// Single stacked percentage bar of bark types.
class _BarkTypeBar extends StatelessWidget {
  final Map<String, double> percentages;
  const _BarkTypeBar({required this.percentages});

  @override
  Widget build(BuildContext context) {
    final entries = SgSummaryCard._sorted(percentages);
    if (entries.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (final e in entries)
              Expanded(
                flex: (e.value * 10).round().clamp(1, 1000),
                child: Container(
                    color: WimzStatus.barkType(context, e.key)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: w.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: w.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  final String? trend;
  const _TrendStat({required this.trend});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    // The arrow icon + "Trend" label carry the state; worsening is the
    // alert case and keeps the error slot.
    final (icon, color) = switch (trend) {
      'improving' => (Icons.trending_down, w.ink),
      'worsening' => (Icons.trending_up, Theme.of(context).colorScheme.error),
      _ => (Icons.trending_flat, w.inkMuted),
    };
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            context.l10n.sgStatTrend,
            style: TextStyle(fontSize: 10, color: w.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  /// Small mark beside the word so the tag never relies on colour alone.
  final IconData? icon;
  const _Tag(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
