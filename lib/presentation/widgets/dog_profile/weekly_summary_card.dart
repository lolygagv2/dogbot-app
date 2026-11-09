import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/providers/dog_weekly_summary_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Robot 386aef0: per-dog weekly summary (Mon–Sun) on the dog profile.
/// Pulls on first build and on refresh; `headline` is pre-phrased by the
/// robot — display verbatim. Note: per-dog bark counts accrue from
/// 2026-09-01 forward (older rows predate per-dog attribution), so early
/// summaries can undercount vs household totals.
class DogWeeklySummaryCard extends ConsumerStatefulWidget {
  final String dogId;
  final String? dogName;
  const DogWeeklySummaryCard({super.key, required this.dogId, this.dogName});

  @override
  ConsumerState<DogWeeklySummaryCard> createState() =>
      _DogWeeklySummaryCardState();
}

class _DogWeeklySummaryCardState extends ConsumerState<DogWeeklySummaryCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(dogWeeklySummaryProvider(widget.dogId));
      if (state.summary == null && !state.pulling) {
        ref
            .read(dogWeeklySummaryProvider(widget.dogId).notifier)
            .pull(dogName: widget.dogName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dogWeeklySummaryProvider(widget.dogId));
    final s = state.summary;
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WimzTheme.cardDecoration(context, radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.weeklySummaryTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
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
                      onPressed: () => ref
                          .read(
                              dogWeeklySummaryProvider(widget.dogId).notifier)
                          .pull(dogName: widget.dogName),
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
          if (s == null && state.error == null && !state.pulling) ...[
            const SizedBox(height: 4),
            Text(
              l.weeklyTapRefresh,
              style: TextStyle(color: w.inkMuted, fontSize: 12),
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 6),
            if (s.headline != null)
              Text(
                s.headline!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat(l.dogProfileStatBarks, '${s.barks.total}'),
                // Direction is carried by the sign in the delta text
                // ("+12%" / "-8%"), not by a hue.
                _Stat(l.weeklyVsLastWeek, _delta(s.barks)),
                _Stat(l.dogProfileStatTreats, '${s.treatsTotal}'),
                _Stat(l.weeklyQuiets, '${s.guardianSuccessfulQuiets}'),
              ],
            ),
            if (s.barks.byType.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TypeCountBar(counts: s.barks.byType),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final e in _sortedCounts(s.barks.byType))
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
                          '${e.key} ${e.value}',
                          style: TextStyle(fontSize: 11, color: w.inkMuted),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (s.coaching.attempts > 0) ...[
              const SizedBox(height: 8),
              Text(
                s.coaching.successRate != null
                    ? l.weeklyTricksWithRate(
                        s.coaching.completed,
                        s.coaching.attempts,
                        (s.coaching.successRate! * 100).toStringAsFixed(0),
                      )
                    : l.weeklyTricks(
                        s.coaching.completed,
                        s.coaching.attempts,
                      ),
                style: TextStyle(fontSize: 12, color: w.inkMuted),
              ),
            ],
            if (s.guardianInterventions > 0) ...[
              const SizedBox(height: 2),
              Text(
                l.weeklyGuardian(
                  s.guardianInterventions,
                  s.guardianHouseholdSessions,
                ),
                style: TextStyle(fontSize: 12, color: w.inkMuted),
              ),
            ],
            // Robot c032823: honest data-coverage caption — how far back
            // each number really goes after the legacy backfill.
            if (_coverageCaption(context, s.coverage) != null) ...[
              const SizedBox(height: 8),
              Text(
                _coverageCaption(context, s.coverage)!,
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: w.inkMuted,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// "Data since: barks Sep 1 · treats Jul 22 · coaching Dec 27 '25" —
  /// only the metrics the robot reported coverage for; null when none.
  static String? _coverageCaption(
      BuildContext context, Map<String, String> coverage) {
    final l = context.l10n;
    final locale = l.localeName;
    final labels = [
      ('per_bark_since', l.weeklyCoverageBarks),
      ('bark_type_since', l.weeklyCoverageBarkTypes),
      ('treats_since', l.weeklyCoverageTreats),
      ('coaching_since', l.weeklyCoverageCoaching),
    ];
    final parts = <String>[];
    final thisYear = DateTime.now().year;
    for (final (key, label) in labels) {
      final d = DateTime.tryParse(coverage[key] ?? '')?.toLocal();
      if (d == null) continue;
      final date = d.year == thisYear
          ? DateFormat.MMMd(locale).format(d)
          : DateFormat.yMMMd(locale).format(d);
      parts.add('$label $date');
    }
    if (parts.isEmpty) return null;
    return l.weeklyDataSince(parts.join(' · '));
  }

  static String _delta(DogWeeklyBarks b) {
    if (b.changePercent == null) return '—';
    final v = b.changePercent!;
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(0)}%';
  }

  static List<MapEntry<String, int>> _sortedCounts(Map<String, int> m) {
    final entries = m.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

/// Stacked count bar of bark types — same visual language as the SG
/// summary card's percentage bar.
class _TypeCountBar extends StatelessWidget {
  final Map<String, int> counts;
  const _TypeCountBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final entries = _DogWeeklySummaryCardState._sortedCounts(counts);
    if (entries.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (final e in entries)
              Expanded(
                flex: e.value.clamp(1, 1 << 20),
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
