import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import 'mjpeg_viewer.dart';
import 'webrtc_video_view.dart';

/// Smart video view: tries WebRTC first, falls back to MJPEG after timeout.
/// Auto-detects stale video (no frames for 8s) and reconnects.
class SmartVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  const SmartVideoView({super.key, this.deviceId});

  @override
  ConsumerState<SmartVideoView> createState() => _SmartVideoViewState();
}

class _SmartVideoViewState extends ConsumerState<SmartVideoView> {
  bool _useMjpegFallback = false;
  Timer? _fallbackTimer;
  Timer? _staleCheckTimer;
  int _lastVideoWidth = 0;
  int _lastVideoHeight = 0;
  int _staleFrameCount = 0;

  static const _mjpegUrl = 'http://192.168.4.1:8000/camera/stream';
  static const _webrtcTimeout = Duration(seconds: 10);
  static const _staleCheckInterval = Duration(seconds: 4);
  static const _maxStaleChecks = 2; // 2 checks × 4s = 8s before reconnect

  @override
  void initState() {
    super.initState();
    final isLocal = ref.read(settingsProvider).localModeEnabled;
    if (isLocal) {
      _startFallbackTimer();
    }
    _startStaleFrameDetection();
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_webrtcTimeout, () {
      if (!mounted) return;
      final webrtcState = ref.read(webrtcProvider);
      if (webrtcState.state != WebRTCState.connected) {
        print('SmartVideo: WebRTC timeout (10s) — falling back to MJPEG');
        setState(() => _useMjpegFallback = true);
      }
    });
  }

  /// Detect stale video: if renderer dimensions haven't changed for 8 seconds
  /// while WebRTC claims to be connected, force a reconnect.
  void _startStaleFrameDetection() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(_staleCheckInterval, (_) {
      if (!mounted) return;
      final webrtcState = ref.read(webrtcProvider);
      if (webrtcState.state != WebRTCState.connected) {
        _staleFrameCount = 0;
        return;
      }

      final renderer = webrtcState.renderer;
      if (renderer == null) return;

      final w = renderer.videoWidth;
      final h = renderer.videoHeight;

      // If dimensions are 0, video never started — not "stale", just not connected
      if (w == 0 && h == 0) return;

      // Check if dimensions changed (proxy for "frames are flowing")
      if (w == _lastVideoWidth && h == _lastVideoHeight) {
        _staleFrameCount++;
        if (_staleFrameCount >= _maxStaleChecks) {
          print('SmartVideo: Video stale for ${_staleFrameCount * _staleCheckInterval.inSeconds}s — auto-reconnecting');
          _staleFrameCount = 0;
          _reconnectWebRTC();
        }
      } else {
        _staleFrameCount = 0;
        _lastVideoWidth = w;
        _lastVideoHeight = h;
      }
    });
  }

  void _reconnectWebRTC() {
    print('SmartVideo: Forcing WebRTC reconnect');
    ref.read(webrtcProvider.notifier).close();
    // Small delay then re-request
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isLocal = ref.read(settingsProvider).localModeEnabled;
        final deviceId = isLocal ? 'local_robot' : widget.deviceId ?? '';
        if (deviceId.isNotEmpty) {
          ref.read(webrtcProvider.notifier).requestVideoStream(deviceId);
        }
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _staleCheckTimer?.cancel();
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
                  _reconnectWebRTC();
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
