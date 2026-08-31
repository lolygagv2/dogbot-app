import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/sg_summary_provider.dart';
import '../../theme/app_theme.dart';

/// Robot 137a5e8: Silent Guardian session summary card. Shown above the SG
/// event feed — renders the latest sg_summary (auto level-4 escalation or a
/// manual status pull). `headline` and `current_action` are pre-phrased by
/// the robot and displayed verbatim.
class SgSummaryCard extends ConsumerWidget {
  const SgSummaryCard({super.key});

  static const _typeColors = <String, Color>{
    'distress': Colors.deepOrange,
    'demand': Colors.amber,
    'alarm': Colors.redAccent,
    'aggressive': Colors.red,
    'play': Colors.lightGreen,
    'unclassified': Colors.blueGrey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sgSummaryProvider);
    final s = state.summary;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (s?.panicActive ?? false)
              ? AppTheme.error.withOpacity(0.6)
              : Colors.purple.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.purple, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Session Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
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
                      icon: const Icon(Icons.refresh,
                          size: 18, color: Colors.purple),
                      onPressed: () =>
                          ref.read(sgSummaryProvider.notifier).pull(),
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
          if (s == null && state.error == null) ...[
            const SizedBox(height: 4),
            const Text(
              'Tap refresh for a live status report',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 6),
            if (s.headline != null)
              Text(
                s.headline!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            if (s.currentAction != null) ...[
              const SizedBox(height: 2),
              Text(
                s.currentAction!,
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat('Barks', '${s.totalBarks}'),
                _Stat('Treats', '${s.treatsDispensed}'),
                _Stat('Interventions', '${s.interventionsTriggered}'),
                if (s.escalationLevel != null)
                  _Stat('Level', '${s.escalationLevel}',
                      color: s.escalationLevel! >= 4 ? AppTheme.error : null),
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
                            color: _typeColors[e.key] ?? Colors.blueGrey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key} ${e.value.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (s.aggressiveTag || s.panicActive || s.panicEpisodes > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (s.panicActive)
                    const _Tag('PANIC ACTIVE', AppTheme.error),
                  if (!s.panicActive && s.panicEpisodes > 0)
                    _Tag('${s.panicEpisodes} panic episode'
                        '${s.panicEpisodes == 1 ? '' : 's'}', AppTheme.warning),
                  if (s.aggressiveTag)
                    const _Tag('Aggressive behavior', Colors.red),
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
                    color:
                        SgSummaryCard._typeColors[e.key] ?? Colors.blueGrey),
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

class _TrendStat extends StatelessWidget {
  final String? trend;
  const _TrendStat({required this.trend});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trend) {
      'improving' => (Icons.trending_down, Colors.green),
      'worsening' => (Icons.trending_up, AppTheme.error),
      _ => (Icons.trending_flat, AppTheme.textTertiary),
    };
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const Text(
            'Trend',
            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
