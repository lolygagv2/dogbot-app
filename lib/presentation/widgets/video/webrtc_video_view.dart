import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/photo_provider.dart';
import '../../../domain/providers/video_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import '../../theme/app_theme.dart';

/// WebRTC video view widget for displaying live video from robot via relay
class WebRTCVideoView extends ConsumerStatefulWidget {
  final String? deviceId;

  /// When false, the in-video camera + record button overlay is suppressed —
  /// callers that already provide their own non-overlapping placement
  /// (e.g. the drive screen, where the bottom-left is the joystick zone)
  /// can opt out. Defaults to true so the home screen layout is unchanged.
  final bool showOverlayButtons;

  const WebRTCVideoView({
    super.key,
    this.deviceId,
    this.showOverlayButtons = true,
  });

  @override
  ConsumerState<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends ConsumerState<WebRTCVideoView> {
  bool _requestSent = false;
  RTCVideoRenderer? _currentRenderer;
  bool _hasFirstFrame = false;

  // Build 132: NO auto-connect at mount. The auto-started WebRTC attempt
  // raced the WS handshake, lagged, and usually failed before succeeding on
  // a manual retry — so video now starts only from the user's tap (the
  // disconnected placeholder below). Once started, the provider's
  // auto-reconnect machinery keeps it alive as before.

  void _requestVideo() {
    if (_requestSent) return;
    _requestSent = true;

    // In local mode, always use 'local_robot' — no relay device lookup
    final localConn = ref.read(localConnectionProvider);
    final String deviceId;
    if (localConn.isConnected) {
      deviceId = 'local_robot';
    } else if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
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
        // A-BANNER: while the robot isn't reachable, a "Tap to connect" here
        // silently failed (ws.send bails) AND duplicated the MainShell
        // reconnect banner — two tappable connection affordances doing
        // different things. Show a passive state until the transport is up;
        // the banner owns connection recovery.
        if (!ref.watch(connectionProvider).isConnected) {
          return _buildPlaceholder(
              'Waiting for connection...', Icons.videocam_off, null);
        }
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

  Widget _buildPlaceholder(String message, IconData icon, VoidCallback? onTap) {
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
          AbsorbPointer(
            child: Container(
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
          ),
        ],
      );
    }

    // Video is ready - display it with proper sizing
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: SizedBox.expand(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              mirror: false,
            ),
          ),
        ),

        if (widget.showOverlayButtons) ...[
          // Camera button overlay (bottom-left to avoid audio mute toggle on bottom-right)
          Positioned(
            bottom: 16,
            left: 16,
            child: CameraButton(),
          ),

          // Video record button (next to camera button)
          Positioned(
            bottom: 16,
            left: 72,
            child: VideoRecordButton(),
          ),
        ],
      ],
    );
  }
}


/// Video record button widget with pulsing red indicator
class VideoRecordButton extends ConsumerStatefulWidget {
  const VideoRecordButton({super.key});

  @override
  ConsumerState<VideoRecordButton> createState() => VideoRecordButtonState();
}

class VideoRecordButtonState extends ConsumerState<VideoRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoProvider);
    final isRecording = videoState.isRecording;
    final isProcessing = videoState.isProcessing;

    // Drive pulse animation
    if (isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Show toast when video is saved
    ref.listen<VideoState>(videoProvider, (previous, next) {
      if (next.lastCaptured != null &&
          previous?.lastCaptured?.id != next.lastCaptured?.id) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  next.lastCaptured!.savedToGallery
                      ? Icons.check_circle
                      : Icons.videocam,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  next.lastCaptured!.savedToGallery
                      ? 'Video saved to gallery!'
                      : 'Video saved!',
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(videoProvider.notifier).clearLastCaptured();
      }

      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(videoProvider.notifier).clearError();
      }
    });

    final opacity = isRecording
        ? 0.4 + (_pulseController.value * 0.6)
        : 1.0;

    return Material(
      color: isRecording
          ? Colors.red.withOpacity(opacity * 0.6)
          : Colors.black54,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isProcessing
            ? null
            : () {
                if (isRecording) {
                  ref.read(videoProvider.notifier).stopRecording();
                } else {
                  ref.read(videoProvider.notifier).startRecording();
                }
              },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isProcessing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: videoState.downloadProgress > 0
                        ? videoState.downloadProgress
                        : null, // indeterminate until download starts
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  isRecording ? Icons.stop : Icons.videocam,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

/// Camera button widget for taking photos
class CameraButton extends ConsumerWidget {
  const CameraButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(photoProvider);
    final isCapturing = photoState.isCapturing;

    // Show toast when photo is captured
    ref.listen<PhotoState>(photoProvider, (previous, next) {
      if (next.lastCaptured != null &&
          previous?.lastCaptured?.id != next.lastCaptured?.id) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  next.lastCaptured!.savedToGallery
                      ? Icons.check_circle
                      : Icons.photo,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  next.lastCaptured!.savedToGallery
                      ? 'Photo saved to gallery!'
                      : 'Photo saved!',
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(photoProvider.notifier).clearLastCaptured();
      }

      // Show error if any
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(photoProvider.notifier).clearError();
      }
    });

    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isCapturing
            ? null
            : () => ref.read(photoProvider.notifier).takePhoto(),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isCapturing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }
}
