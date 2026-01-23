import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

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
  final double recordingProgress; // 0-1 for recording progress
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

/// Push-to-talk notifier
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  Timer? _progressTimer;
  Timer? _maxDurationTimer;
  DateTime? _recordingStartTime;
  StreamSubscription? _audioMessageSubscription;
  String? _currentRecordingPath;
  bool _isInitialized = false;

  static const _maxRecordingDuration = Duration(seconds: 10);
  static const _audioFormat = 'aac';

  PushToTalkNotifier() : super(const PttStateData()) {
    _init();
  }

  Future<void> _init() async {
    if (Platform.isLinux) return;

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    try {
      await _recorder!.openRecorder();
      await _player!.openPlayer();
      _isInitialized = true;
    } catch (e) {
      print('PushToTalk: Failed to initialize: $e');
    }

    _setupAudioListener();
  }

  void _setupAudioListener() {
    // Listen for incoming audio messages from robot
    _audioMessageSubscription = WebSocketClient.instance.eventStream.listen((event) {
      if (event.type == 'audio_message') {
        _handleIncomingAudio(event.data);
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _maxDurationTimer?.cancel();
    _audioMessageSubscription?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  /// Get temp file path for recording
  Future<String> _getTempRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/ptt_recording_${DateTime.now().millisecondsSinceEpoch}.aac';
  }

  /// Start recording (called on button press)
  Future<bool> startRecording() async {
    if (Platform.isLinux) {
      state = state.copyWith(error: 'Recording not supported on desktop');
      return false;
    }

    if (!_isInitialized || _recorder == null) {
      state = state.copyWith(error: 'Recorder not initialized');
      return false;
    }

    if (state.isBusy) return false;

    try {
      _currentRecordingPath = await _getTempRecordingPath();

      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
      );

      _recordingStartTime = DateTime.now();
      state = state.copyWith(
        state: PttState.recording,
        recordingProgress: 0,
        recordingDurationMs: 0,
      );

      // Progress timer
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_recordingStartTime == null) return;

        final elapsed = DateTime.now().difference(_recordingStartTime!);
        final progress = elapsed.inMilliseconds / _maxRecordingDuration.inMilliseconds;

        state = state.copyWith(
          recordingProgress: progress.clamp(0.0, 1.0),
          recordingDurationMs: elapsed.inMilliseconds,
        );
      });

      // Max duration timer - auto stop at 10 seconds
      _maxDurationTimer = Timer(_maxRecordingDuration, () {
        stopRecordingAndSend();
      });

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and send audio (called on button release)
  Future<bool> stopRecordingAndSend() async {
    if (state.state != PttState.recording) return false;

    _progressTimer?.cancel();
    _maxDurationTimer?.cancel();

    try {
      await _recorder?.stopRecorder();
      final durationMs = state.recordingDurationMs;
      final path = _currentRecordingPath;

      if (path == null) {
        state = state.copyWith(state: PttState.idle, error: 'Recording failed');
        return false;
      }

      // Minimum recording length (300ms)
      if (durationMs < 300) {
        state = state.copyWith(state: PttState.idle);
        try {
          await File(path).delete();
        } catch (_) {}
        return false;
      }

      state = state.copyWith(state: PttState.sending);

      // Read and encode as base64
      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Send via WebSocket
      WebSocketClient.instance.sendAudioMessage(base64Data, _audioFormat, durationMs);

      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}

      state = state.copyWith(state: PttState.idle);
      return true;
    } catch (e) {
      state = state.copyWith(state: PttState.idle, error: 'Failed to send: $e');
      return false;
    }
  }

  /// Cancel recording without sending
  Future<void> cancelRecording() async {
    if (state.state != PttState.recording) return;

    _progressTimer?.cancel();
    _maxDurationTimer?.cancel();

    try {
      await _recorder?.stopRecorder();
      if (_currentRecordingPath != null) {
        try {
          await File(_currentRecordingPath!).delete();
        } catch (_) {}
      }
    } catch (_) {}

    state = state.copyWith(state: PttState.idle);
  }

  /// Request audio from robot (listen button)
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    state = state.copyWith(state: PttState.requesting);
    WebSocketClient.instance.requestAudioFromRobot(durationSeconds);

    // Timeout after duration + 2 seconds
    Future.delayed(Duration(seconds: durationSeconds + 2), () {
      if (state.state == PttState.requesting) {
        state = state.copyWith(state: PttState.idle);
      }
    });
  }

  /// Handle incoming audio from robot
  Future<void> _handleIncomingAudio(Map<String, dynamic> data) async {
    if (Platform.isLinux || _player == null) return;

    try {
      final base64Data = data['data'] as String?;
      if (base64Data == null || base64Data.isEmpty) return;

      state = state.copyWith(state: PttState.playing);

      // Decode and save to temp file
      final bytes = base64Decode(base64Data);
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/ptt_incoming_${DateTime.now().millisecondsSinceEpoch}.aac';

      await File(path).writeAsBytes(bytes);

      // Play the audio
      await _player!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
        whenFinished: () {
          state = state.copyWith(state: PttState.idle);
          // Clean up
          try {
            File(path).delete();
          } catch (_) {}
        },
      );
    } catch (e) {
      state = state.copyWith(state: PttState.idle, error: 'Playback failed: $e');
    }
  }

  /// Stop any ongoing playback
  Future<void> stopPlayback() async {
    if (state.state == PttState.playing) {
      await _player?.stopPlayer();
      state = state.copyWith(state: PttState.idle);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
