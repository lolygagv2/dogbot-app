import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/webrtc_provider.dart';

/// Small speaker mute/unmute toggle overlaid on video feed.
/// Purely app-side — does NOT send any command to the robot.
class AudioMuteToggle extends ConsumerWidget {
  const AudioMuteToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(webrtcAudioMutedProvider);
    final isConnected = ref.watch(webrtcStateProvider) == WebRTCState.connected;

    // Only show when WebRTC is connected
    if (!isConnected) return const SizedBox.shrink();

    return GestureDetector(
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
        child: Icon(
          isMuted ? Icons.volume_off : Icons.volume_up,
          color: isMuted ? Colors.white54 : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
