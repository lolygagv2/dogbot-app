import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import 'mjpeg_viewer.dart';
import 'webrtc_video_view.dart';

/// Smart video view: tries WebRTC first, falls back to MJPEG after timeout.
/// In relay mode, always uses WebRTC (relay brokers signaling reliably).
/// In local mode, tries WebRTC for 10s then falls back to MJPEG.
class SmartVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  const SmartVideoView({super.key, this.deviceId});

  @override
  ConsumerState<SmartVideoView> createState() => _SmartVideoViewState();
}

class _SmartVideoViewState extends ConsumerState<SmartVideoView> {
  bool _useMjpegFallback = false;
  Timer? _fallbackTimer;

  static const _mjpegUrl = 'http://192.168.4.1:8000/camera/stream';
  static const _webrtcTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    final isLocal = ref.read(settingsProvider).localModeEnabled;
    if (isLocal) {
      _startFallbackTimer();
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_webrtcTimeout, () {
      if (!mounted) return;
      // Check if WebRTC connected in time
      final webrtcState = ref.read(webrtcProvider);
      if (webrtcState.state != WebRTCState.connected) {
        print('SmartVideo: WebRTC timeout (10s) — falling back to MJPEG');
        setState(() => _useMjpegFallback = true);
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = ref.watch(settingsProvider).localModeEnabled;

    // Relay mode: always WebRTC
    if (!isLocal) {
      return WebRTCVideoView(deviceId: widget.deviceId);
    }

    // Local mode with MJPEG fallback active
    if (_useMjpegFallback) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const MjpegViewer(streamUrl: _mjpegUrl),
          // Small button to retry WebRTC
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => _useMjpegFallback = false);
                  _startFallbackTimer();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hd, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Try WebRTC',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Local mode: try WebRTC, cancel fallback timer if it connects
    final webrtcState = ref.watch(webrtcProvider);
    if (webrtcState.state == WebRTCState.connected) {
      _fallbackTimer?.cancel();
    }

    return WebRTCVideoView(deviceId: widget.deviceId);
  }
}
