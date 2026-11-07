import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/agent_talk_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// "Talk to WIM-Z" — hold the mic to record (≤ 30 s), release to send to
/// the relay voice agent. Shows the last exchange (You / WIM-Z) and where the
/// reply is playing (robot, or this phone when the robot is offline).
class TalkToWimzCard extends ConsumerWidget {
  const TalkToWimzCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(agentTalkProvider);
    final isLocal = ref.watch(settingsProvider).localModeEnabled;
    final notifier = ref.read(agentTalkProvider.notifier);

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

    final disabled = isLocal || s.isBusy;
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
          _HoldButton(
            recording: s.isRecording,
            busy: s.isBusy,
            disabled: disabled,
            progress: (s.elapsedMs / AgentTalkNotifier.maxMs).clamp(0.0, 1.0),
            onDown: () => notifier.startRecording(),
            onUp: () => notifier.stopAndSend(),
            onCancel: () => notifier.cancel(),
          ),
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

/// Press-and-hold mic. Pointer events (not long-press) so recording starts
/// the instant the finger lands; a drag off the button cancels.
class _HoldButton extends StatelessWidget {
  final bool recording;
  final bool busy;
  final bool disabled;
  final double progress;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancel;

  const _HoldButton({
    required this.recording,
    required this.busy,
    required this.disabled,
    required this.progress,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = recording
        ? AppTheme.error
        : disabled
            ? AppTheme.textTertiary
            : AppTheme.primary;
    return Listener(
      onPointerDown: disabled ? null : (_) => onDown(),
      onPointerUp: disabled ? null : (_) => onUp(),
      onPointerCancel: disabled ? null : (_) => onCancel(),
      child: Semantics(
        button: true,
        label: context.l10n.talkHold,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (recording || busy)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: busy ? null : progress,
                    strokeWidth: 3,
                    color: color,
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: recording ? 58 : 52,
                height: recording ? 58 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(recording ? 0.35 : 0.18),
                  border: Border.all(color: color, width: 2),
                  boxShadow: recording
                      ? AppTheme.glowShadow(color, blur: 14)
                      : null,
                ),
                child: Icon(
                  busy ? Icons.hourglass_top : Icons.mic,
                  color: color,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
