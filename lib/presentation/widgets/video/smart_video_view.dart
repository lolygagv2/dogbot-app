import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import 'mjpeg_viewer.dart';
import 'webrtc_video_view.dart';

/// Smart video view: tries WebRTC first, falls back to MJPEG after timeout.
/// In relay mode, always uses WebRTC.
/// In local mode, tries WebRTC for 10s then falls back to MJPEG.
class SmartVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  /// Forwarded to WebRTCVideoView. False suppresses the in-video
  /// camera/record button overlay so a parent screen can render them in a
  /// non-overlapping spot (see drive_screen — joystick lives at bottom-left).
  final bool showOverlayButtons;

  const SmartVideoView({
    super.key,
    this.deviceId,
    this.showOverlayButtons = true,
  });

  @override
  ConsumerState<SmartVideoView> createState() => _SmartVideoViewState();
}

class _SmartVideoViewState extends ConsumerState<SmartVideoView> {
  bool _useMjpegFallback = false;
  Timer? _fallbackTimer;

  // Legacy fallback only — the live URL is resolved (probed) at connect time
  // and read from localConnectionProvider.mjpegUrl. Robot now serves
  // /video/feed; /camera/stream was the old path.
  static const _mjpegUrl = 'http://192.168.4.1:8000/video/feed';
  // On the robot AP there is no STUN/TURN, so ICE can never reach `connected`.
  // Keep this short so a WebRTC attempt that will never succeed flips to MJPEG
  // fast instead of spinning on "connecting" (robot-Claude check #2).
  static const _webrtcTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    // Build 112: local AP mode DEFAULTS to the reliable MJPEG stream. WebRTC in
    // local mode dies ~100s in (robot-side ICE consent-freshness / Pi load) and
    // can't be fixed app-side, so we don't bet the live view on it. Users can
    // tap "Try WebRTC" for the crisp low-latency stream when the link is happy;
    // if it then drops we return to MJPEG automatically (see build()).
    final isLocal = ref.read(settingsProvider).localModeEnabled;
    if (isLocal) {
      _useMjpegFallback = true;
    }
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

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = ref.watch(settingsProvider).localModeEnabled;

    // Build 132: relay mode with no robot selected — there is nothing to
    // connect to, so keep the video area blank (no "Tap to connect" that can
    // never succeed). An explicit deviceId from the parent overrides.
    if (!isLocal &&
        widget.deviceId == null &&
        !ref.watch(hasSelectedDeviceProvider)) {
      return Container(color: Colors.black);
    }

    // Build 112: if the user opted into WebRTC (local mode) and it drops after
    // connecting, fall straight back to the reliable MJPEG stream instead of
    // freezing on "buffering". Harmless in relay mode (which ignores the flag).
    ref.listen<WebRTCConnectionState>(webrtcProvider, (prev, next) {
      final dropped = prev?.state == WebRTCState.connected &&
          next.state != WebRTCState.connected;
      if (dropped && !_useMjpegFallback && mounted) {
        print('SmartVideo: WebRTC dropped after connecting — back to MJPEG');
        setState(() => _useMjpegFallback = true);
      }
    });

    // Relay mode: always WebRTC
    if (!isLocal) {
      return WebRTCVideoView(
      deviceId: widget.deviceId,
      showOverlayButtons: widget.showOverlayButtons,
    );
    }

    // Local mode with MJPEG fallback active
    if (_useMjpegFallback) {
      // Use the endpoint resolved (probed) at connect time so we don't 404 on
      // an endpoint rename. A-DISCOVER: the robot may be at its home-WiFi IP,
      // not the AP — derive the fallback URL from the connected IP too.
      final local = ref.watch(localConnectionProvider);
      final streamUrl = local.mjpegUrl ??
          (local.robotIp != null
              ? 'http://${local.robotIp}:${local.port}/video/feed'
              : _mjpegUrl);
      return Stack(
        fit: StackFit.expand,
        children: [
          MjpegViewer(streamUrl: streamUrl),
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
                  // Build 132: WebRTCVideoView no longer auto-connects at
                  // mount, so this opt-in must fire the request itself.
                  final localConn = ref.read(localConnectionProvider);
                  ref.read(webrtcProvider.notifier).requestVideoStream(
                        localConn.isConnected
                            ? 'local_robot'
                            : widget.deviceId ?? ref.read(deviceIdProvider),
                      );
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

    return WebRTCVideoView(
      deviceId: widget.deviceId,
      showOverlayButtons: widget.showOverlayButtons,
    );
  }
}
