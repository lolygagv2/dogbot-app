import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/agent_talk_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Press-and-hold mic for the relay voice agent ("Ask WIM-Z"): hold to
/// record, release to send; the robot speaks the answer back. Pointer
/// events (not long-press) so recording starts the instant the finger
/// lands; a drag off the button cancels. [size] 64 on the dog profile,
/// 42 in the Home mode row.
class HoldToTalkButton extends ConsumerWidget {
  final double size;

  /// When set, renders as a labelled pill (Home mode row, next to DRIVE)
  /// instead of a bare circle.
  final String? label;
  const HoldToTalkButton({super.key, this.size = 64, this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(agentTalkProvider);
    final isLocal = ref.watch(settingsProvider).localModeEnabled;
    final n = ref.read(agentTalkProvider.notifier);
    final recording = s.isRecording;
    final busy = s.isBusy;
    final disabled = isLocal || busy;
    final progress = (s.elapsedMs / AgentTalkNotifier.maxMs).clamp(0.0, 1.0);
    // Ink/primary throughout (the Home row's one gold element is Treat);
    // recording fills solid, with on-primary text/ring.
    final cs = Theme.of(context).colorScheme;
    final w = context.wimz;
    final color = disabled ? w.inkDisabled : cs.primary;
    final onFill = cs.onPrimary;
    final inner = size - 12;

    if (label != null) {
      return Listener(
        onPointerDown: disabled ? null : (_) => n.startRecording(),
        onPointerUp: disabled ? null : (_) => n.stopAndSend(),
        onPointerCancel: disabled ? null : (_) => n.cancel(),
        child: Tooltip(
          message: context.l10n.talkHold,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: recording ? color : w.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                else if (recording)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        value: progress, strokeWidth: 2, color: onFill),
                  )
                else
                  Icon(Icons.record_voice_over, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  recording
                      ? (s.elapsedMs / 1000).toStringAsFixed(0)
                      : label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: recording ? onFill : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Listener(
      onPointerDown: disabled ? null : (_) => n.startRecording(),
      onPointerUp: disabled ? null : (_) => n.stopAndSend(),
      onPointerCancel: disabled ? null : (_) => n.cancel(),
      child: Tooltip(
        message: context.l10n.talkHold,
        child: Semantics(
          button: true,
          label: context.l10n.talkCardTitle,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (recording || busy)
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: busy ? null : progress,
                      strokeWidth: size > 50 ? 3 : 2,
                      color: color,
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: recording ? inner + 6 : inner,
                  height: recording ? inner + 6 : inner,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recording ? color : w.surfaceRaised,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    busy ? Icons.hourglass_top : Icons.record_voice_over,
                    color: recording ? onFill : color,
                    size: size > 50 ? 26 : 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status + last exchange for the voice agent, for screens that only have
/// room for the compact button (Home). Visible while recording / thinking /
/// playing, on error, and for [linger] after a reply; otherwise collapsed.
class AskWimzBanner extends ConsumerStatefulWidget {
  final Duration linger;
  const AskWimzBanner({super.key, this.linger = const Duration(seconds: 15)});

  @override
  ConsumerState<AskWimzBanner> createState() => _AskWimzBannerState();
}

class _AskWimzBannerState extends ConsumerState<AskWimzBanner> {
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(agentTalkProvider);

    // Re-render once the linger window after the last reply closes.
    ref.listen<DateTime?>(agentTalkProvider.select((st) => st.replyAt), (_, at) {
      _hide?.cancel();
      if (at != null) {
        _hide = Timer(widget.linger, () {
          if (mounted) setState(() {});
        });
      }
    });

    final recent = s.replyAt != null &&
        DateTime.now().difference(s.replyAt!) < widget.linger;
    final show = s.phase != AgentTalkPhase.idle || s.error != null || recent;
    if (!show) return const SizedBox.shrink();

    final w = context.wimz;
    final isError = s.phase == AgentTalkPhase.idle && s.error != null;
    String status;
    Color color = w.inkMuted;
    switch (s.phase) {
      case AgentTalkPhase.recording:
        status = l.talkRecording((s.elapsedMs / 1000).toStringAsFixed(1));
        color = w.ink;
        break;
      case AgentTalkPhase.sending:
        status = l.talkSending;
        color = w.ink;
        break;
      case AgentTalkPhase.playingRobot:
        status = l.talkPlayingRobot;
        color = w.ink;
        break;
      case AgentTalkPhase.playingPhone:
        status = l.talkPlayingPhone;
        color = w.ink;
        break;
      case AgentTalkPhase.idle:
        status = s.error ?? l.talkCardTitle;
        // Genuine error: error colour + error icon + the message text.
        if (isError) color = Theme.of(context).colorScheme.error;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: w.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.record_voice_over,
                  size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(status,
                    style: TextStyle(fontSize: 12, color: color),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (recent && s.textIn != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${l.talkYou}: ${s.textIn!}',
                  style: TextStyle(fontSize: 12, color: w.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          if (recent && s.textOut != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('WIM-Z: ${s.textOut!}',
                  style: TextStyle(fontSize: 12, color: w.ink),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
          for (final r in s.refused.take(2))
            if (recent)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l.talkRefused(r),
                    style: TextStyle(fontSize: 11, color: w.inkMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
        ],
      ),
    );
  }
}
