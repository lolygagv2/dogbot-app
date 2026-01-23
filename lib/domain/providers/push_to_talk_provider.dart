import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';

/// Push-to-talk state
enum PttState {
  idle,
  recording,
  sending,
  requesting,
  playing,
}

/// Push-to-talk state data
class PttStateData {
  final PttState state;
  final double recordingProgress;
  final int recordingDurationMs;
  final String? error;

  const PttStateData({
    this.state = PttState.idle,
    this.recordingProgress = 0,
    this.recordingDurationMs = 0,
    this.error,
  });

  PttStateData copyWith({
    PttState? state,
    double? recordingProgress,
    int? recordingDurationMs,
    String? error,
  }) {
    return PttStateData(
      state: state ?? this.state,
      recordingProgress: recordingProgress ?? this.recordingProgress,
      recordingDurationMs: recordingDurationMs ?? this.recordingDurationMs,
      error: error,
    );
  }

  bool get isRecording => state == PttState.recording;
  bool get isPlaying => state == PttState.playing;
  bool get isBusy => state != PttState.idle;
}

/// Provider for push-to-talk state
final pushToTalkProvider =
    StateNotifierProvider<PushToTalkNotifier, PttStateData>((ref) {
  return PushToTalkNotifier();
});

/// Push-to-talk notifier - STUBBED (recording only works on mobile builds)
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  StreamSubscription? _audioMessageSubscription;

  PushToTalkNotifier() : super(const PttStateData()) {
    _setupAudioListener();
  }

  void _setupAudioListener() {
    _audioMessageSubscription = WebSocketClient.instance.eventStream.listen((event) {
      if (event.type == 'audio_message') {
        // Audio playback stubbed - would need platform-specific implementation
        print('PushToTalk: Received audio message (playback stubbed)');
      }
    });
  }

  @override
  void dispose() {
    _audioMessageSubscription?.cancel();
    super.dispose();
  }

  /// Start recording - STUBBED
  Future<bool> startRecording() async {
    state = state.copyWith(error: 'Recording requires mobile app (iOS/Android)');
    return false;
  }

  /// Stop recording - STUBBED
  Future<bool> stopRecordingAndSend() async {
    return false;
  }

  /// Cancel recording - STUBBED
  Future<void> cancelRecording() async {
    state = state.copyWith(state: PttState.idle);
  }

  /// Request audio from robot
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    state = state.copyWith(state: PttState.requesting);
    WebSocketClient.instance.requestAudioFromRobot(durationSeconds);

    Future.delayed(Duration(seconds: durationSeconds + 2), () {
      if (state.state == PttState.requesting) {
        state = state.copyWith(state: PttState.idle);
      }
    });
  }

  /// Stop playback - STUBBED
  Future<void> stopPlayback() async {
    state = state.copyWith(state: PttState.idle);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
