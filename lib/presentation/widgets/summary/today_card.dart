import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ai_connection.dart';
import '../../../data/models/daily_summary.dart';
import '../../../domain/providers/daily_summary_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// "Today" card — relay roll-up GET /summary/{dog}/today (brief 2026-11-06
/// §1). Renders from counts/totals alone; episodes, headline and an AI plan
/// appear only when the server sends them. When the relay has no events
/// for the day it falls back to counts derived from this phone's activity
/// feed so the card is never blank. [compact] = demo view (one stat row).
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
    final isLocalMode = ref.watch(settingsProvider).localModeEnabled;
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
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
    final hasRelayTotals = s != null &&
        (stats.pacingSeconds > 0 ||
            stats.musicSeconds > 0 ||
            stats.aloneSeconds > 0 ||
            stats.missionRuns > 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WimzTheme.cardDecoration(context, radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dogName != null
                      ? '${l.todayCardTitle} · $dogName'
                      : l.todayCardTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateLabel,
                style: TextStyle(fontSize: 11, color: w.inkMuted),
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
                      icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                      onPressed: () => ref
                          .read(dailySummaryProvider(dogId).notifier)
                          .load(refresh: true),
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
                color: cs.onSurface,
              ),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(l.todayStatBarks, '${stats.barks}', w.ink),
              // Relay brief 2026-11-09 §4: totals.treat_cap null = no daily
              // limit → label says "Unlimited" (never 0 or blank). A locally
              // built summary has no cap info, so it keeps the plain label.
              _Stat(
                stats.isRelayRollup && stats.treatCap == null
                    ? l.todayStatTreatsUnlimited
                    : l.todayStatTreats,
                stats.treatCap != null
                    ? '${stats.treats}/${stats.treatCap}'
                    : '${stats.treats}',
                w.ink,
              ),
              _Stat(l.todayStatGuardian, '${stats.guardianInterventions}',
                  w.ink),
              if (stats.settleMedianS != null)
                _Stat(l.todayStatSettle, _fmtSeconds(stats.settleMedianS!),
                    w.ink)
              else if (s != null && stats.quietMinutes > 0)
                _Stat(l.todayStatQuiet, _fmtSeconds(stats.quietMinutes * 60),
                    w.ink)
              else
                _Stat(
                  l.todayStatCoaching,
                  stats.coachingAttempts > 0
                      ? '${stats.coachingCompleted}/${stats.coachingAttempts}'
                      : '${stats.sits}',
                  w.ink,
                ),
            ],
          ),
          if (!compact && hasRelayTotals) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat(l.todayStatPacing, _fmtSeconds(stats.pacingSeconds),
                    w.inkMuted, small: true),
                _Stat(l.todayStatMusic, _fmtSeconds(stats.musicSeconds),
                    w.inkMuted, small: true),
                _Stat(l.todayStatAlone, _fmtSeconds(stats.aloneSeconds),
                    w.inkMuted, small: true),
                _Stat(
                  l.todayStatMissions,
                  stats.missionRuns > 0
                      ? '${stats.missionsSuccess}/${stats.missionRuns}'
                      : '0',
                  w.inkMuted,
                  small: true,
                ),
              ],
            ),
          ],
          if (s?.plan != null) ...[
            const SizedBox(height: 10),
            _PlanBlock(plan: s!.plan!, compact: compact),
          ],
          if (!compact && s != null && s.episodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.todayEpisodes.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, letterSpacing: 0.5, color: w.inkMuted),
            ),
            const SizedBox(height: 4),
            for (final e in s.episodes.take(3)) _EpisodeRow(e, locale),
          ],
          if (!compact && s != null && s.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.todayHighlights.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, letterSpacing: 0.5, color: w.inkMuted),
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
                          style: TextStyle(fontSize: 12, color: w.inkMuted),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        h.text,
                        style: TextStyle(fontSize: 12, color: w.inkMuted),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fetch error: same muted ink as the other captions, plus a
                // warning icon so the state is not carried by colour alone.
                if (state.error != null) ...[
                  Icon(Icons.warning_amber, size: 13, color: w.inkMuted),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    state.error != null
                        ? l.todayCardError
                        : state.loading
                            ? l.loading
                            : (state.notFound && !isLocalMode)
                                ? l.todayCardEmptyRelay
                                : l.todayCardLocalCounts,
                    style: TextStyle(fontSize: 11, color: w.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 45 → "45s", 310 → "5m", 4000 → "1h 6m"
  static String _fmtSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
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

class _EpisodeRow extends StatelessWidget {
  final DailyEpisode e;
  final String locale;
  const _EpisodeRow(this.e, this.locale);

  /// High = error (with a warning icon beside the dot), medium = ink,
  /// low / unknown = ink-muted.
  static Color _severityColor(BuildContext context, String? s) => switch (s) {
        'high' => Theme.of(context).colorScheme.error,
        'med' || 'medium' => context.wimz.ink,
        _ => context.wimz.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final isHigh = e.severity == 'high';
    final time = e.ts != null ? DateFormat.jm(locale).format(e.ts!.toLocal()) : '';
    final settled = e.settleS != null
        ? ' · ${l.todayEpisodeSettled(TodayCard._fmtSeconds(e.settleS!))}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _severityColor(context, e.severity),
            ),
          ),
          if (isHigh)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.warning_amber,
                  size: 12, color: _severityColor(context, e.severity)),
            ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(time,
                  style: TextStyle(fontSize: 12, color: w.inkMuted)),
            ),
          Expanded(
            child: Text(
              '${l.todayEpisodeLine(e.barkCount, TodayCard._fmtSeconds(e.durationS))}$settled',
              style: TextStyle(fontSize: 12, color: w.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (e.imageUrl != null)
            Icon(Icons.photo_outlined, size: 14, color: w.inkMuted),
        ],
      ),
    );
  }
}

class _PlanBlock extends StatelessWidget {
  final DailyPlan plan;
  final bool compact;
  const _PlanBlock({required this.plan, required this.compact});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    final source = AiProvider.fromWire(plan.source)?.displayName ??
        plan.source;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: w.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: w.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: cs.onSurface),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  plan.title ??
                      (source != null
                          ? l.todayPlanBy(source)
                          : l.todayPlanTitle),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
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
                style: TextStyle(fontSize: 12, color: w.inkMuted),
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
  final bool small;
  const _Stat(this.label, this.value, this.color, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 13 : 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.wimz.inkMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
