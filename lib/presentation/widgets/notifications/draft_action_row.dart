import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/ai_connection.dart';
import '../../../domain/providers/mission_drafts_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Approve / Decline for a drafted mission, rendered inside its feed tile.
/// Shows the relay mission definition (type · trigger · duration · reward ·
/// goal · warnings); status comes from missionDraftsProvider and once
/// decided it collapses to a chip.
class DraftActionRow extends ConsumerWidget {
  final String draftId;
  const DraftActionRow({super.key, required this.draftId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(missionDraftProvider(draftId));
    final l = context.l10n;
    if (entry == null) {
      // Draft predates this app session and the relay list didn't have it —
      // nothing to act on.
      return _chip(l.draftStatusExpired, AppTheme.textTertiary);
    }
    switch (entry.status) {
      case DraftStatus.approved:
        return _chip(l.draftStatusApproved, AppTheme.accent);
      case DraftStatus.declined:
        return _chip(l.draftStatusDeclined, AppTheme.textTertiary);
      case DraftStatus.expired:
        return _chip(l.draftStatusExpired, AppTheme.textTertiary);
      case DraftStatus.pending:
        break;
    }
    final d = entry.draft;
    final detail = _detailLine(d, l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.summary != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              d.summary!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              detail,
              style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (d.steps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              d.steps.take(3).join(' → '),
              style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        for (final w in d.warnings.take(2))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: AppTheme.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    w,
                    style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: entry.busy
                    ? null
                    : () => ref
                        .read(missionDraftsProvider.notifier)
                        .decide(draftId, DraftDecision.approve),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l.draftApprove),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: entry.busy
                    ? null
                    : () => ref
                        .read(missionDraftsProvider.notifier)
                        .decide(draftId, DraftDecision.decline),
                icon: const Icon(Icons.close, size: 16),
                label: Text(l.draftDecline),
              ),
            ),
            if (entry.busy) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        if (entry.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              entry.error!,
              style: const TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ),
      ],
    );
  }

  /// "recall · Starts after you leave · 2 min · 1 treats"
  static String? _detailLine(MissionDraft d, AppLocalizations l) {
    final parts = <String>[];
    if (d.missionType != null && d.missionType != d.title) {
      parts.add(d.missionType!);
    }
    switch (d.triggerKind) {
      case 'departure':
        parts.add(l.draftTriggerDeparture);
        break;
      case 'schedule':
        parts.add(l.draftTriggerSchedule(d.triggerTime ?? '--:--'));
        break;
      case 'manual':
        if (d.durationS != null) parts.add(l.draftTriggerManual);
        break;
    }
    if (d.durationS != null || d.rewardTreats != null) {
      parts.add(l.draftDurationReward(
          ((d.durationS ?? 0) / 60).ceil(), d.rewardTreats ?? 0));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _chip(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      );
}
