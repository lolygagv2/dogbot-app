import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/services/video_service.dart';
import 'connection_provider.dart';

/// State for video recording
class VideoState {
  final bool isRecording;
  final bool isProcessing;
  final DateTime? recordingStartTime;
  final CapturedVideo? lastCaptured;
  final String? error;

  const VideoState({
    this.isRecording = false,
    this.isProcessing = false,
    this.recordingStartTime,
    this.lastCaptured,
    this.error,
  });

  VideoState copyWith({
    bool? isRecording,
    bool? isProcessing,
    DateTime? recordingStartTime,
    CapturedVideo? lastCaptured,
    String? error,
    bool clearLastCaptured = false,
    bool clearError = false,
    bool clearRecordingStart = false,
  }) {
    return VideoState(
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      recordingStartTime: clearRecordingStart
          ? null
          : (recordingStartTime ?? this.recordingStartTime),
      lastCaptured:
          clearLastCaptured ? null : (lastCaptured ?? this.lastCaptured),
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Recording duration in seconds (0 if not recording)
  int get recordingSeconds {
    if (recordingStartTime == null) return 0;
    return DateTime.now().difference(recordingStartTime!).inSeconds;
  }
}

/// Provider for video recording management
final videoProvider =
    StateNotifierProvider<VideoNotifier, VideoState>((ref) {
  return VideoNotifier(ref);
});

/// Video recording state notifier
class VideoNotifier extends StateNotifier<VideoState> {
  final Ref _ref;
  final VideoService _videoService = VideoService.instance;
  StreamSubscription? _videoSubscription;
  Timer? _maxDurationTimer;

  static const _maxRecordingSeconds = 60;
  static const _videoResponseTimeoutSeconds = 45; // Pi encoding takes time

  VideoNotifier(this._ref) : super(const VideoState()) {
    _init();
  }

  Future<void> _init() async {
    await _videoService.init();
    _subscribeToVideo();
  }

  void _subscribeToVideo() {
    final wsClient = _ref.read(websocketClientProvider);
    _videoSubscription?.cancel();
    _videoSubscription = wsClient.videoStream.listen(_handleVideoMessage);
  }

  Future<void> _handleVideoMessage(Map<String, dynamic> message) async {
    _maxDurationTimer?.cancel();

    final base64Data = message['data'] as String?;
    final filename = message['filename'] as String? ?? 'wimz_video';
    final timestamp = message['timestamp'] as String?;

    print('VIDEO: Received video response, keys=${message.keys}');
    print('VIDEO: data length=${base64Data?.length ?? 0}, filename=$filename');

    if (base64Data == null || base64Data.isEmpty) {
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        clearRecordingStart: true,
        error: 'Received empty video data',
      );
      return;
    }

    state = state.copyWith(isRecording: false, isProcessing: true);

    try {
      final video = await _videoService.saveVideo(
        base64Data: base64Data,
        filename: filename,
        timestamp: timestamp,
      );

      state = state.copyWith(
        isProcessing: false,
        lastCaptured: video,
        clearRecordingStart: true,
        clearError: true,
      );

      print('VideoProvider: Video saved: ${video.filename}');
    } catch (e) {
      print('VideoProvider: Failed to save video: $e');
      state = state.copyWith(
        isProcessing: false,
        clearRecordingStart: true,
        error: 'Failed to save video: $e',
      );
    }
  }

  /// Start recording video
  void startRecording() {
    if (state.isRecording || state.isProcessing) return;

    if (!_ref.read(connectionProvider).isConnected) {
      state = state.copyWith(error: 'Not connected to robot');
      return;
    }

    print('VIDEO: Sending start_recording command (max ${_maxRecordingSeconds}s)');

    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      clearError: true,
    );

    _ref.read(websocketClientProvider).sendStartRecording(
      maxSeconds: _maxRecordingSeconds,
    );

    // Auto-stop after max duration
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(
      const Duration(seconds: _maxRecordingSeconds),
      () {
        if (state.isRecording) {
          print('VIDEO: Auto-stopping after ${_maxRecordingSeconds}s max duration');
          stopRecording();
        }
      },
    );
  }

  /// Stop recording video
  void stopRecording() {
    if (!state.isRecording) return;

    _maxDurationTimer?.cancel();
    print('VIDEO: Sending stop_recording command');
    state = state.copyWith(isRecording: false, isProcessing: true);

    _ref.read(websocketClientProvider).sendStopRecording();
    print('VIDEO: Waiting for video response (timeout: ${_videoResponseTimeoutSeconds}s)...');

    // Timeout waiting for video data — video encoding on Pi takes time
    _maxDurationTimer = Timer(Duration(seconds: _videoResponseTimeoutSeconds), () {
      if (state.isProcessing) {
        print('VIDEO: TIMEOUT — no response after ${_videoResponseTimeoutSeconds}s');
        state = state.copyWith(
          isProcessing: false,
          clearRecordingStart: true,
          error: 'Video save timed out — no response after ${_videoResponseTimeoutSeconds}s',
        );
      }
    });
  }

  /// Clear the last captured notification
  void clearLastCaptured() {
    state = state.copyWith(clearLastCaptured: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _videoSubscription?.cancel();
    super.dispose();
  }
}
