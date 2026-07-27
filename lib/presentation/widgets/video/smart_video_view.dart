import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/video_transport_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import 'mjpeg_viewer.dart';
import 'webrtc_video_view.dart';

/// Smart video view — a thin renderer over the app-global video session.
///
/// Relay mode: always WebRTC (user-initiated per Build 132).
/// Local mode (robot brief 2026-07-27 §5b): WebRTC by default, auto-started
/// via [localVideoTransportProvider]; MJPEG renders only while WebRTC isn't
/// connected and the transport arbiter has flipped to fallback. A connected
/// WebRTC session ALWAYS wins — that both shows the burned-in bounding boxes
/// and unmounts the MJPEG player so the two streams never run concurrently
/// (dual streams saturate the robot's AP link — the drive-screen lag).
///
/// Deliberately holds NO transport state of its own: per-screen fallback
/// state resetting on navigation was why the drive screen ran MJPEG next to
/// a healthy WebRTC session.
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
  // Legacy fallback only — the live URL is resolved (probed) at connect time
  // and read from localConnectionProvider.mjpegUrl. Robot now serves
  // /video/feed; /camera/stream was the old path.
  static const _mjpegUrl = 'http://192.168.4.1:8000/video/feed';

  @override
  void initState() {
    super.initState();
    // Local mode: kick the app-global WebRTC session (idempotent — a no-op
    // when a session is already connected or mid-handshake, so navigating
    // between home/drive/coach never restarts video).
    if (ref.read(settingsProvider).localModeEnabled) {
      ref.read(localVideoTransportProvider.notifier).ensureLocalVideo();
    }
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

    // Relay mode: always WebRTC
    if (!isLocal) {
      return WebRTCVideoView(
        deviceId: widget.deviceId,
        showOverlayButtons: widget.showOverlayButtons,
      );
    }

    // Local mode. WebRTC-connected always wins; otherwise the transport
    // arbiter decides whether the MJPEG fallback should show while WebRTC
    // keeps (re)trying in the background.
    final webrtcConnected =
        ref.watch(webrtcProvider.select((s) => s.isConnected));
    final useMjpeg = ref.watch(localVideoTransportProvider);

    if (!webrtcConnected && useMjpeg) {
      // Use the endpoint resolved (probed) at connect time so we don't 404 on
      // an endpoint rename. A-DISCOVER: the robot may be at its home-WiFi IP,
      // not the AP — derive the fallback URL from the connected IP too.
      final local = ref.watch(localConnectionProvider);
      final streamUrl = local.mjpegUrl ??
          (local.robotIp != null
              ? 'http://${local.robotIp}:${local.port}/video/feed'
              : _mjpegUrl);
      return MjpegViewer(streamUrl: streamUrl);
    }

    return WebRTCVideoView(
      deviceId: widget.deviceId,
      showOverlayButtons: widget.showOverlayButtons,
    );
  }
}
