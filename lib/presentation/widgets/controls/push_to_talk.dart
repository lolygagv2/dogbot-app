import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/push_to_talk_provider.dart';
import '../../theme/app_theme.dart';

/// Push-to-talk controls widget with mic and listen buttons
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
          _MicButton(state: pttState, compact: true),
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
          _MicButton(state: pttState),
          const SizedBox(width: 12),
          _ListenButton(state: pttState),
        ],
      ),
    );
  }
}

/// Mic button - hold to talk
class _MicButton extends ConsumerWidget {
  final PttStateData state;
  final bool compact;

  const _MicButton({required this.state, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = state.isRecording;
    final isBusy = state.isBusy && !isRecording;
    final size = compact ? 44.0 : 56.0;
    final iconSize = compact ? 24.0 : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: isBusy ? null : (_) => _startRecording(ref),
          onTapUp: isRecording ? (_) => _stopRecording(ref) : null,
          onTapCancel: isRecording ? () => _cancelRecording(ref) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? Colors.red
                  : (isBusy ? Colors.grey : AppTheme.primary),
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
                      value: state.recordingProgress,
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                // Mic icon
                Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  size: iconSize,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            isRecording
                ? '${(state.recordingDurationMs / 1000).toStringAsFixed(1)}s'
                : 'Hold to talk',
            style: TextStyle(
              fontSize: 10,
              color: isRecording ? Colors.red : AppTheme.textSecondary,
              fontWeight: isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _startRecording(WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(pushToTalkProvider.notifier).startRecording();
    if (!success) {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _stopRecording(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(pushToTalkProvider.notifier).stopRecordingAndSend();
  }

  Future<void> _cancelRecording(WidgetRef ref) async {
    await ref.read(pushToTalkProvider.notifier).cancelRecording();
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
