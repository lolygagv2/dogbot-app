import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../data/services/webrtc_service.dart';
import '../../../domain/providers/webrtc_provider.dart';
import '../../theme/app_theme.dart';

/// WebRTC video view widget for displaying live video from robot via relay
class WebRTCVideoView extends ConsumerStatefulWidget {
  final String deviceId;

  const WebRTCVideoView({super.key, required this.deviceId});

  @override
  ConsumerState<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends ConsumerState<WebRTCVideoView> {
  WebRTCService? _service;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  Future<void> _initializeWebRTC() async {
    _service = ref.read(webrtcServiceProvider);
    if (_service != null) {
      await _service!.initialize();
      setState(() => _initialized = true);

      // Request video stream from the device
      _service!.requestVideoStream(widget.deviceId);
    }
  }

  @override
  void dispose() {
    _service?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webrtcState = ref.watch(webrtcStateProvider);

    if (!_initialized || _service == null) {
      return _buildLoading('Initializing...');
    }

    switch (webrtcState) {
      case WebRTCState.disconnected:
        return _buildLoading('Disconnected');
      case WebRTCState.connecting:
        return _buildLoading('Connecting...');
      case WebRTCState.error:
        return _buildError();
      case WebRTCState.connected:
        return _buildVideo();
    }
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

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Video connection failed',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _service?.requestVideoStream(widget.deviceId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Container(
      color: Colors.black,
      child: RTCVideoView(
        _service!.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }
}
