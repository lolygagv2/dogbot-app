import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/push_to_talk_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Push-to-talk controls widget with mic toggle and listen buttons
class PushToTalkControls extends ConsumerStatefulWidget {
  final bool compact;

  const PushToTalkControls({super.key, this.compact = false});

  @override
  ConsumerState<PushToTalkControls> createState() => _PushToTalkControlsState();
}

class _PushToTalkControlsState extends ConsumerState<PushToTalkControls> {
  String? _lastShownError;

  @override
  Widget build(BuildContext context) {
    final pttState = ref.watch(pushToTalkProvider);

    // Show error snackbar when error changes
    if (pttState.error != null && pttState.error != _lastShownError) {
      _lastShownError = pttState.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.onError, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pttState.error!)),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: context.l10n.dismiss,
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: () {
                  ref.read(pushToTalkProvider.notifier).clearError();
                },
              ),
            ),
          );
        }
      });
    } else if (pttState.error == null) {
      _lastShownError = null;
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicToggleButton(state: pttState, compact: true),
          const SizedBox(width: 8),
          _ListenButton(state: pttState, compact: true),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.wimz.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.wimz.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicToggleButton(state: pttState),
          const SizedBox(width: 12),
          _ListenButton(state: pttState),
        ],
      ),
    );
  }
}

/// Mic button — single tap to start 5-second recording, auto-sends when done.
/// No manual stop needed. Tap once → records 5s → sends → "Sent" confirmation.
class _MicToggleButton extends ConsumerStatefulWidget {
  final PttStateData state;
  final bool compact;

  const _MicToggleButton({required this.state, this.compact = false});

  @override
  ConsumerState<_MicToggleButton> createState() => _MicToggleButtonState();
}

class _MicToggleButtonState extends ConsumerState<_MicToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pttState = widget.state;
    final isRecording = pttState.isRecording;
    final isSending = pttState.state == PttState.sending;
    final isSent = pttState.isSent;
    final isBusy = isRecording || isSending;
    final size = widget.compact ? 48.0 : 56.0;
    final iconSize = widget.compact ? 24.0 : 28.0;

    // Drive pulse animation
    if (isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Countdown: remaining seconds
    final remainingMs = PushToTalkNotifier.maxRecordingDurationMs - pttState.recordingDurationMs;
    final remainingSec = (remainingMs / 1000).ceil().clamp(0, 5);

    // Button color: primary fill throughout (sent = check icon, recording =
    // pulsing primary + countdown, busy = disabled ink). No red.
    final cs = Theme.of(context).colorScheme;
    final w = context.wimz;
    final onFill = cs.onPrimary;
    Color bgColor;
    if (isSent) {
      bgColor = cs.primary;
    } else if (isRecording) {
      final pulse = 0.7 + (_pulseController.value * 0.3);
      bgColor = cs.primary.withValues(alpha: pulse);
    } else if (isBusy) {
      bgColor = w.inkDisabled;
    } else {
      bgColor = cs.primary;
    }

    // Label text
    final l = context.l10n;
    String label;
    if (isSent) {
      label = l.pttSent;
    } else if (isRecording) {
      label = l.pttSeconds(remainingSec);
    } else if (isSending) {
      label = l.pttSending;
    } else {
      label = l.pttTalk;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          // Single tap starts recording. 5s auto-stop + auto-send. No second tap needed.
          onTap: isBusy
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  final success = await ref.read(pushToTalkProvider.notifier).startRecording();
                  if (!success) {
                    HapticFeedback.heavyImpact();
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring when recording
                if (isRecording)
                  SizedBox(
                    width: size - 8,
                    height: size - 8,
                    child: CircularProgressIndicator(
                      value: pttState.recordingProgress,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(onFill),
                      backgroundColor: onFill.withValues(alpha: 0.24),
                    ),
                  ),
                // Sending spinner
                if (isSending)
                  SizedBox(
                    width: size - 16,
                    height: size - 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(onFill),
                    ),
                  ),
                // Show countdown number inside button when recording (always visible)
                if (isRecording)
                  Text(
                    '$remainingSec',
                    style: TextStyle(
                      color: onFill,
                      fontSize: iconSize,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Icon(
                    isSent
                        ? Icons.check
                        : (isRecording ? Icons.stop : Icons.mic),
                    size: iconSize,
                    color: onFill,
                  ),
              ],
            ),
          ),
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSent || isRecording ? w.ink : w.inkMuted,
              fontWeight: isRecording || isSent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }
}

/// Listen button - tap to hear from robot
class _ListenButton extends ConsumerWidget {
  final PttStateData state;
  final bool compact;

  const _ListenButton({required this.state, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = state.isPlaying;
    final isRequesting = state.state == PttState.requesting;
    final isBusy = state.isBusy && !isPlaying && !isRequesting;
    final size = compact ? 44.0 : 56.0;
    final iconSize = compact ? 24.0 : 28.0;

    // Playing = solid primary fill; requesting = sunken fill with a
    // spinner; idle = raised fill with a primary outline. The icon and
    // (non-compact) label carry the state.
    final cs = Theme.of(context).colorScheme;
    final w = context.wimz;
    final fg = isPlaying ? cs.onPrimary : (isBusy ? w.inkDisabled : w.ink);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isBusy
              ? null
              : (isPlaying
                  ? () => _stopPlayback(ref)
                  : () => _requestAudio(ref)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying
                  ? cs.primary
                  : (isRequesting || isBusy
                      ? w.surfaceSunken
                      : w.surfaceRaised),
              border: Border.all(
                color: isPlaying || isRequesting
                    ? Colors.transparent
                    : cs.primary,
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Loading indicator when requesting
                if (isRequesting)
                  SizedBox(
                    width: size - 12,
                    height: size - 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  ),
                // Icon
                Icon(
                  isPlaying
                      ? Icons.volume_up
                      : (isRequesting ? Icons.hearing : Icons.hearing_outlined),
                  size: iconSize,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            isPlaying
                ? context.l10n.pttPlaying
                : (isRequesting
                    ? context.l10n.pttListening
                    : context.l10n.pttTapToListen),
            style: TextStyle(
              fontSize: 10,
              color: isPlaying ? w.ink : w.inkMuted,
              fontWeight:
                  isPlaying || isRequesting ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  void _requestAudio(WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(pushToTalkProvider.notifier).requestAudio();
  }

  Future<void> _stopPlayback(WidgetRef ref) async {
    await ref.read(pushToTalkProvider.notifier).stopPlayback();
  }
}

/// Mic-only PTT widget (no listen button — replaced by always-on audio streaming)
class PushToTalkMicOnly extends ConsumerStatefulWidget {
  final bool compact;

  const PushToTalkMicOnly({super.key, this.compact = false});

  @override
  ConsumerState<PushToTalkMicOnly> createState() => _PushToTalkMicOnlyState();
}

class _PushToTalkMicOnlyState extends ConsumerState<PushToTalkMicOnly> {
  String? _lastShownError;

  @override
  Widget build(BuildContext context) {
    final pttState = ref.watch(pushToTalkProvider);

    if (pttState.error != null && pttState.error != _lastShownError) {
      _lastShownError = pttState.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.onError, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pttState.error!)),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    } else if (pttState.error == null) {
      _lastShownError = null;
    }

    return _MicToggleButton(state: pttState, compact: widget.compact);
  }
}

/// Floating push-to-talk overlay for video screens
class PushToTalkOverlay extends StatelessWidget {
  final Alignment alignment;

  const PushToTalkOverlay({
    super.key,
    this.alignment = Alignment.bottomLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: alignment == Alignment.bottomLeft ? 16 : null,
      right: alignment == Alignment.bottomRight ? 16 : null,
      bottom: 16,
      child: const PushToTalkControls(),
    );
  }
}
