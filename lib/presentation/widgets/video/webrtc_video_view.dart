import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../domain/providers/webrtc_provider.dart';
import '../../theme/app_theme.dart';

/// Default device ID for WIM-Z robot
const String kDefaultDeviceId = 'wimz_robot_01';

/// WebRTC video view widget for displaying live video from robot via relay
class WebRTCVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  const WebRTCVideoView({super.key, this.deviceId});

  @override
  ConsumerState<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends ConsumerState<WebRTCVideoView> {
  bool _requestSent = false;

  @override
  void initState() {
    super.initState();
    // Request video on next frame to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestVideo();
    });
  }

  void _requestVideo() {
    if (_requestSent) return;
    _requestSent = true;

    final deviceId = widget.deviceId ?? kDefaultDeviceId;
    ref.read(webrtcProvider.notifier).requestVideoStream(deviceId);
  }

  @override
  void dispose() {
    // Don't close connection on dispose - let the provider manage lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webrtcState = ref.watch(webrtcProvider);

    switch (webrtcState.state) {
      case WebRTCState.disconnected:
        return _buildPlaceholder('Tap to connect', Icons.videocam_off, () {
          _requestSent = false;
          _requestVideo();
        });
      case WebRTCState.connecting:
        return _buildLoading('Connecting video...');
      case WebRTCState.error:
        return _buildError(webrtcState.errorMessage);
      case WebRTCState.connected:
        return _buildVideo(webrtcState.renderer);
    }
  }

  Widget _buildPlaceholder(String message, IconData icon, VoidCallback onTap) {
    return Container(
      color: Colors.black,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String? errorMessage) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Video connection failed',
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _requestSent = false;
                _requestVideo();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(RTCVideoRenderer? renderer) {
    if (renderer == null) {
      return _buildLoading('Initializing renderer...');
    }

    // Debug: log renderer state
    print('WebRTC Widget: renderer srcObject=${renderer.srcObject != null}, size=${renderer.videoWidth}x${renderer.videoHeight}');

    if (renderer.srcObject == null) {
      return _buildLoading('Waiting for video stream...');
    }

    return Container(
      color: Colors.black,
      child: RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        mirror: false,  // Don't mirror remote video
      ),
    );
  }
}
