import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/dog_weekly_summary_provider.dart';
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Weekly Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
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
                      icon: const Icon(Icons.refresh,
                          size: 18, color: AppTheme.primary),
                      onPressed: () => ref
                          .read(
                              dogWeeklySummaryProvider(widget.dogId).notifier)
                          .pull(dogName: widget.dogName),
                    ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: const TextStyle(color: AppTheme.warning, fontSize: 12),
            ),
          ],
          if (s == null && state.error == null && !state.pulling) ...[
            const SizedBox(height: 4),
            const Text(
              'Tap refresh for this week\'s report',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 6),
            if (s.headline != null)
              Text(
                s.headline!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat('Barks', '${s.barks.total}'),
                _Stat('vs last wk', _delta(s.barks),
                    color: switch (s.barks.trend) {
                      'down' => Colors.green,
                      'up' => AppTheme.error,
                      _ => null,
                    }),
                _Stat('Treats', '${s.treatsTotal}'),
                _Stat('Quiets', '${s.guardianSuccessfulQuiets}'),
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
                            color: AppTheme.barkTypeColors[e.key] ??
                                Colors.blueGrey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key} ${e.value}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (s.coaching.attempts > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Tricks: ${s.coaching.completed}/${s.coaching.attempts}'
                ' completed'
                '${s.coaching.successRate != null ? ' (${(s.coaching.successRate! * 100).toStringAsFixed(0)}%)' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            if (s.guardianInterventions > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Guardian: ${s.guardianInterventions} interventions across '
                '${s.guardianHouseholdSessions} sessions',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
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
                    color:
                        AppTheme.barkTypeColors[e.key] ?? Colors.blueGrey),
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
  final Color? color;
  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}
