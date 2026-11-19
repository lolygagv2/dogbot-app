import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/daily_summary.dart';
import '../../../data/models/notification_event.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/daily_summary_provider.dart';
import '../../../domain/providers/demo_replay_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../notifications/attachment_thumb.dart';

/// Silent Guardian pane of the demo view, drawn from the relay's day
/// summary for [dogId] (`GET /summary/{dog}/{date}`) — the recorded day, not
/// the robot's live session. The status line shows the replay's state and
/// virtual clock while a replay is loaded for this dog, otherwise whether
/// the robot is on guard now.
class DemoGuardianPanel extends ConsumerWidget {
  final String dogId;
  const DemoGuardianPanel({super.key, required this.dogId});

  static String fmtSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  static String kindLabel(AppLocalizations l, String kind) => switch (kind) {
        'sound' => l.demoSgKindSound,
        'voice' => l.demoSgKindVoice,
        'treat' => l.demoSgKindTreat,
        'approach' => l.demoSgKindApproach,
        'music' => l.demoSgKindMusic,
        'ultrasonic' => l.demoSgKindUltrasonic,
        'smart_plug' => l.demoSgKindSmartPlug,
        _ => kind,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = context.wimz;
    final day = ref.watch(dailySummaryProvider(dogId));
    final s = day.summary;
    final stats = s?.stats;
    final locale = Localizations.localeOf(context).toString();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(dogId: dogId, date: s?.date),
          const SizedBox(height: 6),
          if (stats == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  day.loading
                      ? l.loading
                      : (day.error ?? l.demoSgNoData),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: w.inkMuted, fontSize: 13),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                _Stat(l.todayStatOnGuard, fmtSeconds(stats.guardSeconds)),
                _Stat(l.demoSgBarkEpisodes, '${stats.barks}'),
                _Stat(l.sgStatInterventions,
                    '${stats.guardianInterventions}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Stat(
                    l.demoSgMedianSettle,
                    stats.settleMedianS != null
                        ? fmtSeconds(stats.settleMedianS!)
                        : '–'),
                _Stat(
                    l.demoSgLongestSettle,
                    stats.settleMaxS != null
                        ? fmtSeconds(stats.settleMaxS!)
                        : '–'),
                _Stat(
                    l.sgStatTreats,
                    stats.treatCap != null
                        ? '${stats.treats}/${stats.treatCap}'
                        : '${stats.treats}'),
              ],
            ),
            if (stats.interventionsByKind.values.any((v) => v > 0)) ...[
              const SizedBox(height: 6),
              Text(
                [
                  for (final e in stats.interventionsByKind.entries)
                    if (e.value > 0) '${kindLabel(l, e.key)} ${e.value}',
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: w.inkMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
          if (day.weekCompare != null) ...[
            const SizedBox(height: 6),
            _WeekLine(day.weekCompare!),
          ],
          if (s != null && s.episodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l.todayEpisodes.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: w.inkMuted),
            ),
            const SizedBox(height: 4),
            for (final e in s.episodes.take(3))
              _Episode(e: e, dogId: dogId, locale: locale),
          ],
        ],
      ),
    );
  }
}

/// Replay state + virtual clock when this dog's replay is loaded; the live
/// robot's guard state otherwise. The summary's date sits on the right.
class _StatusLine extends ConsumerWidget {
  final String dogId;
  final String? date;
  const _StatusLine({required this.dogId, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    final replay = ref.watch(demoReplayProvider);
    final IconData icon;
    final String text;
    final Color color;
    if (replay.replayIsFor(dogId)) {
      final status = switch (replay.replay.status) {
        'loaded' => l.demoReplayStatusLoaded,
        'running' => l.demoReplayStatusRunning,
        'paused' => l.demoReplayStatusPaused,
        'done' => l.demoReplayStatusDone,
        final other => other,
      };
      final clock = replay.virtualWallTimeFor(dogId);
      icon = replay.replay.isRunning ? Icons.play_circle_fill : Icons.history;
      // replay.virtual_mode: the replay's mode, never the real robot's.
      final vMode =
          replay.statusDogId == dogId ? replay.statusVirtualMode : null;
      text = [
        l.demoSgReplay(status),
        if (vMode != null) robotModeIdLabel(l, vMode),
        if (clock != null)
          l.demoVirtualClock(DateFormat.Hm().format(clock)),
      ].join(' · ');
      color = cs.primary;
    } else {
      final mode = ref.watch(displayModeProvider);
      final onGuard = mode == RobotMode.silentGuardian;
      if (ref.watch(robotAsleepProvider)) {
        icon = Icons.bedtime;
        text = l.modelRobotModeSleep;
        color = w.ink;
      } else {
        icon = onGuard ? Icons.shield : Icons.shield_outlined;
        text = onGuard ? l.demoSgLive : l.demoSgIdle;
        color = onGuard ? w.ink : w.inkMuted;
      }
    }
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (date != null && date!.isNotEmpty)
          Text(date!, style: TextStyle(fontSize: 11, color: w.inkMuted)),
      ],
    );
  }
}

/// "Barking down 42% vs last week" (barking per day; arrow + words, so the
/// direction never rests on colour).
class _WeekLine extends StatelessWidget {
  final BarkWeekCompare c;
  const _WeekLine(this.c);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final pct = c.pctChange;
    final IconData icon;
    final String text;
    final Color color;
    if (pct == null) {
      icon = Icons.trending_flat;
      text = l.demoSgBarkNoBaseline;
      color = w.inkMuted;
    } else if (pct.round() == 0) {
      icon = Icons.trending_flat;
      text = l.demoSgBarkSame;
      color = w.inkMuted;
    } else if (pct < 0) {
      icon = Icons.trending_down;
      text = l.demoSgBarkDown(pct.abs().round());
      color = w.ink;
    } else {
      icon = Icons.trending_up;
      text = l.demoSgBarkUp(pct.round());
      color = Theme.of(context).colorScheme.error;
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: w.ink)),
          Text(label,
              style: TextStyle(fontSize: 9, color: w.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// One top episode: still (tap to open), time, barks · length · settle, and
/// the escalation steps in order.
class _Episode extends ConsumerWidget {
  final DailyEpisode e;
  final String dogId;
  final String locale;
  const _Episode({required this.e, required this.dogId, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    final high = e.severity == 'high';
    final time =
        e.ts != null ? DateFormat.jm(locale).format(e.ts!.toLocal()) : '';
    final settled = e.settleS != null
        ? ' · ${l.todayEpisodeSettled(DemoGuardianPanel.fmtSeconds(e.settleS!))}'
        : '';
    final image = absolutizeAttachmentUrl(e.imageUrl);
    final token = ref.watch(authProvider.select((a) => a.token));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null) ...[
            AttachmentThumb(
              size: 40,
              imageUrl: image,
              authedImageUrl:
                  token == null ? null : eventPhotoUrl(dogId, e.eventId),
              imageHeaders:
                  token == null ? null : {'Authorization': 'Bearer $token'},
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (high)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.warning_amber,
                            size: 12, color: cs.error),
                      ),
                    Expanded(
                      child: Text(
                        '${time.isEmpty ? '' : '$time · '}'
                        '${l.todayEpisodeLine(e.barkCount, DemoGuardianPanel.fmtSeconds(e.durationS))}'
                        '$settled',
                        style: TextStyle(
                            fontSize: 12, color: high ? cs.error : w.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (e.interventions.isNotEmpty)
                  Text(
                    e.interventions
                        .map((k) => DemoGuardianPanel.kindLabel(l, k))
                        .join(' → '),
                    style: TextStyle(fontSize: 11, color: w.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
