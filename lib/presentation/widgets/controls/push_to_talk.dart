import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/push_to_talk_provider.dart';
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
              content: Text(pttState.error!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
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
        color: AppTheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder),
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

    // Button color
    Color bgColor;
    if (isSent) {
      bgColor = AppTheme.accent;
    } else if (isRecording) {
      final pulse = 0.7 + (_pulseController.value * 0.3);
      bgColor = Colors.red.withOpacity(pulse);
    } else if (isBusy) {
      bgColor = Colors.grey;
    } else {
      bgColor = AppTheme.primary;
    }

    // Label text
    String label;
    if (isSent) {
      label = 'Sent \u2713';
    } else if (isRecording) {
      label = '${remainingSec}s';
    } else if (isSending) {
      label = 'Sending...';
    } else {
      label = 'Talk';
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
              boxShadow: isRecording
                  ? [
                      BoxShadow(
                        color: Colors.red.withAlpha(128),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
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
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                // Sending spinner
                if (isSending)
                  SizedBox(
                    width: size - 16,
                    height: size - 16,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                // Show countdown number inside button when recording (always visible)
                if (isRecording)
                  Text(
                    '$remainingSec',
                    style: TextStyle(
                      color: Colors.white,
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
                    color: Colors.white,
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
              color: isSent
                  ? AppTheme.accent
                  : (isRecording ? Colors.red : AppTheme.textSecondary),
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
                  ? Colors.green
                  : (isRequesting
                      ? Colors.orange
                      : (isBusy ? Colors.grey : AppTheme.surfaceLight)),
              border: Border.all(
                color: isPlaying || isRequesting
                    ? Colors.transparent
                    : AppTheme.primary,
                width: 2,
              ),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: Colors.green.withAlpha(128),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Loading indicator when requesting
                if (isRequesting)
                  SizedBox(
                    width: size - 12,
                    height: size - 12,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                // Icon
                Icon(
                  isPlaying
                      ? Icons.volume_up
                      : (isRequesting ? Icons.hearing : Icons.hearing_outlined),
                  size: iconSize,
                  color: isPlaying || isRequesting
                      ? Colors.white
                      : AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            isPlaying
                ? 'Playing...'
                : (isRequesting ? 'Listening...' : 'Tap to listen'),
            style: TextStyle(
              fontSize: 10,
              color: isPlaying
                  ? Colors.green
                  : (isRequesting ? Colors.orange : AppTheme.textSecondary),
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
              content: Text(pttState.error!),
              backgroundColor: Colors.red.shade700,
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
