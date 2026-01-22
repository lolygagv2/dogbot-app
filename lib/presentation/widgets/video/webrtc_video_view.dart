import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import '../../theme/app_theme.dart';

/// WebRTC video view widget for displaying live video from robot via relay
class WebRTCVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  const WebRTCVideoView({super.key, this.deviceId});

  @override
  ConsumerState<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends ConsumerState<WebRTCVideoView> {
  bool _requestSent = false;
  RTCVideoRenderer? _currentRenderer;
  bool _hasFirstFrame = false;

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

    // Use widget deviceId if provided, otherwise use stored device ID from provider
    final String deviceId;
    if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
      deviceId = widget.deviceId!;
    } else {
      deviceId = ref.read(deviceIdProvider);
    }
    ref.read(webrtcProvider.notifier).requestVideoStream(deviceId);
  }

  void _setupRendererListener(RTCVideoRenderer renderer) {
    if (_currentRenderer == renderer) return;

    // Remove old listener
    _currentRenderer?.removeListener(_onRendererChanged);

    // Add new listener
    _currentRenderer = renderer;
    _hasFirstFrame = false;
    renderer.addListener(_onRendererChanged);

    // Also set up onFirstFrameRendered callback
    renderer.onFirstFrameRendered = () {
      print('WebRTC Widget: First frame rendered!');
      _hasFirstFrame = true;
      if (mounted) setState(() {});
    };
  }

  void _onRendererChanged() {
    // Renderer notifies when video dimensions change
    if (mounted && _currentRenderer != null) {
      final w = _currentRenderer!.videoWidth;
      final h = _currentRenderer!.videoHeight;
      print('WebRTC Widget: Renderer changed, size=${w}x$h');
      if (w > 0 && h > 0) {
        setState(() {
          _hasFirstFrame = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _currentRenderer?.removeListener(_onRendererChanged);
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

    // Set up listener for dimension changes
    _setupRendererListener(renderer);

    final w = renderer.videoWidth;
    final h = renderer.videoHeight;

    // Debug: log renderer state
    print('WebRTC Widget: srcObject=${renderer.srcObject != null}, size=${w}x$h, hasFirstFrame=$_hasFirstFrame');

    if (renderer.srcObject == null) {
      return _buildLoading('Waiting for video stream...');
    }

    // Show loading until we have valid dimensions
    if (w == 0 || h == 0) {
      return Stack(
        children: [
          // Keep RTCVideoView in tree so it can receive frames
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              mirror: false,
            ),
          ),
          // Overlay loading indicator
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Receiving video...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Video is ready - display it with proper sizing
    return Container(
      color: Colors.black,
      child: SizedBox.expand(
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          mirror: false,
        ),
      ),
    );
  }
}
