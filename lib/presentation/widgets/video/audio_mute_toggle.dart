import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/webrtc_provider.dart';

/// Small speaker mute/unmute toggle overlaid on video feed.
/// Purely app-side — does NOT send any command to the robot.
///
/// The toggle works in every robot mode. The robot's audio track is always-on
/// (v1.3 contract) and its mic feeds bark detection and WebRTC simultaneously,
/// so app-side playback never interferes with SG/Coach/Mission monitoring.
/// (The old mode-lock here silently pinned users to their persisted mute
/// state — usually muted — with no way out, which read as "mic broken"
/// exactly when they most wanted to listen in. See 2026-08-06 mic brief.)
///
/// During auto-listen (after PTT send), shows a pulsing cyan icon.
class AudioMuteToggle extends ConsumerWidget {
  const AudioMuteToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(webrtcAudioMutedProvider);
    final isConnected = ref.watch(webrtcStateProvider) == WebRTCState.connected;
    final isAutoListening = ref.watch(webrtcAutoListeningProvider);

    // Only show when WebRTC is connected
    if (!isConnected) return const SizedBox.shrink();

    return Tooltip(
      message: isAutoListening
          ? 'Listening to robot...'
          : (isMuted ? 'Unmute audio' : 'Mute audio'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(webrtcProvider.notifier).toggleAudioMute();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isAutoListening
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
