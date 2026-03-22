import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/services/video_service.dart';
import 'connection_provider.dart';

/// State for video recording
class VideoState {
  final bool isRecording;
  final bool isProcessing;
  final double downloadProgress; // 0.0 to 1.0 during download
  final DateTime? recordingStartTime;
  final CapturedVideo? lastCaptured;
  final String? error;

  const VideoState({
    this.isRecording = false,
    this.isProcessing = false,
    this.downloadProgress = 0.0,
    this.recordingStartTime,
    this.lastCaptured,
    this.error,
  });

  VideoState copyWith({
    bool? isRecording,
    bool? isProcessing,
    double? downloadProgress,
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
      downloadProgress: downloadProgress ?? this.downloadProgress,
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

  /// Whether currently downloading video from robot
  bool get isDownloading => isProcessing && downloadProgress > 0 && downloadProgress < 1.0;
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
  static const _videoResponseTimeoutSeconds = 45;

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

    final downloadUrl = message['download_url'] as String? ?? message['url'] as String?;
    final filename = message['filename'] as String? ?? 'wimz_video';
    final timestamp = message['timestamp'] as String?;

    print('VIDEO: Received video_ready, keys=${message.keys}');
    print('VIDEO: download_url=$downloadUrl, filename=$filename');

    if (downloadUrl == null || downloadUrl.isEmpty) {
      print('VIDEO: ERROR — no download_url in video_ready response');
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        downloadProgress: 0,
        clearRecordingStart: true,
        error: 'No download URL received from robot',
      );
      return;
    }

    state = state.copyWith(
      isRecording: false,
      isProcessing: true,
      downloadProgress: 0,
    );

    try {
      print('VIDEO: Starting download from $downloadUrl');
      final video = await _videoService.downloadAndSaveVideo(
        downloadUrl: downloadUrl,
        filename: filename,
        timestamp: timestamp,
        onProgress: (progress) {
          if (mounted) {
            state = state.copyWith(downloadProgress: progress);
          }
        },
      );

      state = state.copyWith(
        isProcessing: false,
        downloadProgress: 1.0,
        lastCaptured: video,
        clearRecordingStart: true,
        clearError: true,
      );

      print('VIDEO: Saved to gallery: ${video.filename}');
    } catch (e) {
      print('VIDEO: Download/save failed: $e');
      state = state.copyWith(
        isProcessing: false,
        downloadProgress: 0,
        clearRecordingStart: true,
        error: 'Failed to download video: $e',
      );
    }
  }

  /// Start recording video — sends record_video command with duration.
  /// Robot records for the duration then sends video_ready with download_url.
  /// User can tap again to stop early via stop_recording command.
  void startRecording({int durationSeconds = 15}) {
    if (state.isRecording || state.isProcessing) return;

    if (!_ref.read(connectionProvider).isConnected) {
      state = state.copyWith(error: 'Not connected to robot');
      return;
    }

    print('VIDEO: Sending record_video command (duration=${durationSeconds}s)');

    _ref.read(websocketClientProvider).sendRecordVideo(
      duration: durationSeconds,
    );

    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      downloadProgress: 0,
      clearError: true,
    );

    // After the recording duration, robot will encode and send video_ready.
    // Switch UI from "recording" to "processing" when duration expires.
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(
      Duration(seconds: durationSeconds),
      () {
        if (state.isRecording && mounted) {
          print('VIDEO: Recording duration complete, waiting for video_ready...');
          state = state.copyWith(isRecording: false, isProcessing: true);
          _startResponseTimeout();
        }
      },
    );
  }

  /// Stop recording early (before duration expires) — sends stop_recording.
  /// Robot will encode what was recorded and send video_ready.
  void stopRecording() {
    if (!state.isRecording) return;

    _maxDurationTimer?.cancel();
    print('VIDEO: Sending stop_recording command (early stop)');

    _ref.read(websocketClientProvider).sendStopRecording();

    state = state.copyWith(isRecording: false, isProcessing: true, downloadProgress: 0);
    _startResponseTimeout();
  }

  /// Start timeout waiting for video_ready response after recording stops
  void _startResponseTimeout() {
    print('VIDEO: Waiting for video_ready (timeout: ${_videoResponseTimeoutSeconds}s)...');
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(Duration(seconds: _videoResponseTimeoutSeconds), () {
      if (state.isProcessing && mounted) {
        print('VIDEO: TIMEOUT — no video_ready after ${_videoResponseTimeoutSeconds}s');
        state = state.copyWith(
          isProcessing: false,
          downloadProgress: 0,
          clearRecordingStart: true,
          error: 'Video encoding timed out — no response after ${_videoResponseTimeoutSeconds}s',
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
