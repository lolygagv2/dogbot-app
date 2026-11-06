import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ai_connection.dart';
import '../../../data/models/daily_summary.dart';
import '../../../domain/providers/daily_summary_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// "Today" card — GET /summary/{dog}/{date}. Renders fully with stats only
/// (no headline, no AI plan); when the server has no row for today it falls
/// back to counts derived from this phone's activity feed so the card is
/// never blank. [compact] trims highlights for the demo view.
class TodayCard extends ConsumerWidget {
  final String dogId;
  final String? dogName;
  final bool compact;

  const TodayCard({
    super.key,
    required this.dogId,
    this.dogName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailySummaryProvider(dogId));
    final local = ref.watch(dogDailySummaryProvider(dogId));
    final l = context.l10n;
    final s = state.summary;
    final usingLocal = s == null;

    final stats = s?.stats ??
        DailyStats(
          barks: local.barkCount,
          treats: local.treatCount,
          sits: local.sitCount,
          coachingAttempts: local.missionCount,
          coachingCompleted: local.missionSuccessCount,
        );
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.MMMEd(locale).format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dogName != null
                      ? '${l.todayCardTitle} · $dogName'
                      : l.todayCardTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateLabel,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textTertiary),
              ),
              const SizedBox(width: 4),
              state.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.refresh,
                          size: 18, color: AppTheme.primary),
                      onPressed: () =>
                          ref.read(dailySummaryProvider(dogId).notifier).load(),
                    ),
            ],
          ),
          if (s?.headline != null) ...[
            const SizedBox(height: 6),
            Text(
              s!.headline!,
              style: TextStyle(
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(l.todayStatBarks, '${stats.barks}', Colors.orange),
              _Stat(l.todayStatTreats, '${stats.treats}', AppTheme.accent),
              _Stat(
                l.todayStatCoaching,
                stats.coachingAttempts > 0
                    ? '${stats.coachingCompleted}/${stats.coachingAttempts}'
                    : '${stats.sits}',
                AppTheme.primary,
              ),
              if (s != null && stats.quietMinutes > 0)
                _Stat(l.todayStatQuiet, _fmtMinutes(stats.quietMinutes),
                    Colors.purple)
              else
                _Stat(l.todayStatGuardian, '${stats.guardianInterventions}',
                    Colors.purple),
            ],
          ),
          if (s?.plan != null) ...[
            const SizedBox(height: 10),
            _PlanBlock(plan: s!.plan!, compact: compact),
          ],
          if (!compact && s != null && s.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.todayHighlights.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 0.5, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 4),
            for (final h in s.highlights.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h.time != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _fmtHighlightTime(h, locale),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textTertiary),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        h.text,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (usingLocal) ...[
            const SizedBox(height: 6),
            Text(
              state.error != null
                  ? l.todayCardError
                  : (state.loading ? l.loading : l.todayCardLocalCounts),
              style: TextStyle(
                fontSize: 11,
                color: state.error != null
                    ? AppTheme.warning
                    : AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtMinutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  static String _fmtHighlightTime(DailyHighlight h, String locale) {
    final inst = h.instant;
    if (inst != null) return DateFormat.jm(locale).format(inst.toLocal());
    return h.time ?? '';
  }
}

class _PlanBlock extends StatelessWidget {
  final DailyPlan plan;
  final bool compact;
  const _PlanBlock({required this.plan, required this.compact});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final source = AiProvider.fromWire(plan.source)?.displayName ??
        plan.source;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppTheme.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  plan.title ??
                      (source != null
                          ? l.todayPlanBy(source)
                          : l.todayPlanTitle),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          for (final item in plan.items.take(compact ? 2 : 4))
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
