import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/agent_talk_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../controls/ask_wimz.dart';

/// "AI voice" — hold the mic to record (≤ 30 s), release to send to the
/// relay voice agent. Shows the last exchange (You / WIM-Z) and where the
/// reply is playing (robot, or this phone when the robot is offline). The
/// same button also sits in the Home mode row; this card is the full view.
class TalkToWimzCard extends ConsumerWidget {
  const TalkToWimzCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(agentTalkProvider);
    final isLocal = ref.watch(settingsProvider).localModeEnabled;

    final String status;
    Color statusColor = AppTheme.textTertiary;
    if (s.error != null && s.phase == AgentTalkPhase.idle) {
      status = s.error!;
      statusColor = AppTheme.warning;
    } else {
      switch (s.phase) {
        case AgentTalkPhase.recording:
          status = l.talkRecording((s.elapsedMs / 1000).toStringAsFixed(1));
          statusColor = AppTheme.error;
          break;
        case AgentTalkPhase.sending:
          status = l.talkSending;
          statusColor = AppTheme.primary;
          break;
        case AgentTalkPhase.playingRobot:
          status = l.talkPlayingRobot;
          statusColor = AppTheme.accent;
          break;
        case AgentTalkPhase.playingPhone:
          status = l.talkPlayingPhone;
          statusColor = AppTheme.accent;
          break;
        case AgentTalkPhase.idle:
          status = isLocal
              ? l.talkErrLocal
              : s.unsupported
                  ? l.talkUnsupported
                  : (s.textOut == null ? l.talkHint : l.talkHold);
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.isRecording
              ? AppTheme.error.withOpacity(0.7)
              : AppTheme.glassBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HoldToTalkButton(size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.talkCardTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 12, color: statusColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.textIn != null) ...[
                  const SizedBox(height: 6),
                  _Line(speaker: l.talkYou, text: s.textIn!, mine: true),
                ],
                if (s.textOut != null) ...[
                  const SizedBox(height: 2),
                  _Line(speaker: 'WIM-Z', text: s.textOut!, mine: false),
                ],
                for (final r in s.refused.take(2)) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.talkRefused(r),
                    style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String speaker;
  final String text;
  final bool mine;
  const _Line({required this.speaker, required this.text, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$speaker: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: mine ? AppTheme.textSecondary : AppTheme.primary,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
