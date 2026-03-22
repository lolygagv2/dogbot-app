import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';

/// Small speaker mute/unmute toggle overlaid on video feed.
/// Purely app-side — does NOT send any command to the robot.
///
/// When SG/Coach/Mission mode is active, the toggle is locked because
/// the robot's microphone is used for bark detection / active monitoring.
///
/// During auto-listen (after PTT send), shows a pulsing cyan icon.
class AudioMuteToggle extends ConsumerWidget {
  const AudioMuteToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(webrtcAudioMutedProvider);
    final isConnected = ref.watch(webrtcStateProvider) == WebRTCState.connected;
    final currentMode = ref.watch(displayModeProvider);
    final isAutoListening = ref.watch(webrtcAutoListeningProvider);

    // Only show when WebRTC is connected
    if (!isConnected) return const SizedBox.shrink();

    final isModeLocked = currentMode == RobotMode.silentGuardian ||
        currentMode == RobotMode.coach ||
        currentMode == RobotMode.mission;

    final String? modeLabel = switch (currentMode) {
      RobotMode.silentGuardian => 'SG',
      RobotMode.coach => 'Coach',
      RobotMode.mission => 'Mission',
      _ => null,
    };

    // Auto-listen indicator (not shown when mode-locked)
    final showAutoListen = isAutoListening && !isModeLocked;

    return Tooltip(
      message: isModeLocked
          ? 'Audio controlled by ${currentMode.label} mode'
          : showAutoListen
              ? 'Listening to robot...'
              : (isMuted ? 'Unmute audio' : 'Mute audio'),
      child: GestureDetector(
        onTap: isModeLocked
            ? null
            : () {
                HapticFeedback.lightImpact();
                ref.read(webrtcProvider.notifier).toggleAudioMute();
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isModeLocked
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white30,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      modeLabel!,
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : showAutoListen
                  ? const _PulsingAutoListenIcon()
                  : Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: isMuted ? Colors.white54 : Colors.white,
                      size: 20,
                    ),
        ),
      ),
    );
  }
}

/// Pulsing cyan speaker icon shown during auto-listen window.
class _PulsingAutoListenIcon extends StatefulWidget {
  const _PulsingAutoListenIcon();

  @override
  State<_PulsingAutoListenIcon> createState() => _PulsingAutoListenIconState();
}

class _PulsingAutoListenIconState extends State<_PulsingAutoListenIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(
        Icons.hearing,
        color: Color(0xFF00E5FF), // Cyan — matches WIM-Z theme
        size: 20,
      ),
    );
  }
}
