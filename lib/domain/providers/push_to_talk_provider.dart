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

/// Push-to-talk notifier - STUBBED (flutter_sound disabled for debugging)
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  StreamSubscription? _audioMessageSubscription;

  PushToTalkNotifier() : super(const PttStateData()) {
    _setupAudioListener();
    print('PushToTalk: Initialized (recording DISABLED for debugging)');
  }

  void _setupAudioListener() {
    _audioMessageSubscription =
        WebSocketClient.instance.eventStream.listen((event) {
      if (event.type == 'audio_message') {
        print('PushToTalk: Received audio message (playback disabled)');
      }
    });
  }

  @override
  void dispose() {
    _audioMessageSubscription?.cancel();
    super.dispose();
  }

  /// Start recording - DISABLED
  Future<bool> startRecording() async {
    print('PushToTalk: Recording DISABLED for debugging white screen');
    state = state.copyWith(
      error: 'Recording temporarily disabled for debugging',
    );
    return false;
  }

  /// Stop recording and send to robot - DISABLED
  Future<bool> stopRecordingAndSend() async {
    return false;
  }

  /// Cancel recording without sending - DISABLED
  Future<void> cancelRecording() async {
    state = state.copyWith(
      state: PttState.idle,
      recordingProgress: 0,
      recordingDurationMs: 0,
    );
  }

  /// Request audio from robot (listen button)
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    print('PushToTalk: Requesting ${durationSeconds}s audio from robot');

    state = state.copyWith(state: PttState.requesting, error: null);
    WebSocketClient.instance.requestAudioFromRobot(durationSeconds);

    // Timeout after duration + 2 seconds
    Future.delayed(Duration(seconds: durationSeconds + 2), () {
      if (state.state == PttState.requesting) {
        print('PushToTalk: Audio request timed out');
        state = state.copyWith(
          state: PttState.idle,
          error: 'No audio received from robot',
        );
      }
    });
  }

  /// Stop playback - DISABLED
  Future<void> stopPlayback() async {
    state = state.copyWith(state: PttState.idle);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Run diagnostics - DISABLED
  Future<String> runDiagnostics() async {
    return '''
=== RECORDING DIAGNOSTICS ===
Status: DISABLED
Reason: flutter_sound temporarily removed to debug white screen issue
=== END DIAGNOSTICS ===
''';
  }
}
