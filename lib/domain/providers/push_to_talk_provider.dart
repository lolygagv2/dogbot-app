import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

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

/// Check if we're on a mobile platform
bool get _isMobilePlatform {
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (e) {
    return false; // Web platform
  }
}

/// Provider for push-to-talk state
final pushToTalkProvider =
    StateNotifierProvider<PushToTalkNotifier, PttStateData>((ref) {
  return PushToTalkNotifier();
});

/// Push-to-talk notifier - Full implementation for mobile, stubbed for desktop
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  StreamSubscription? _audioMessageSubscription;

  // Recording
  AudioRecorder? _recorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;

  // Playback
  AudioPlayer? _audioPlayer;

  // Max recording duration (30 seconds)
  static const int maxRecordingDurationMs = 30000;

  PushToTalkNotifier() : super(const PttStateData()) {
    _setupAudioListener();
    if (_isMobilePlatform) {
      _initRecorder();
      _initPlayer();
    }
  }

  Future<void> _initRecorder() async {
    _recorder = AudioRecorder();
    print('PushToTalk: Recorder initialized');
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      print('PushToTalk: Playback complete');
      if (state.state == PttState.playing) {
        state = state.copyWith(state: PttState.idle);
      }
    });
    print('PushToTalk: Player initialized');
  }

  void _setupAudioListener() {
    _audioMessageSubscription =
        WebSocketClient.instance.eventStream.listen((event) {
      if (event.type == 'audio_message') {
        _handleIncomingAudio(event.data);
      }
    });
  }

  /// Handle incoming audio from robot
  Future<void> _handleIncomingAudio(Map<String, dynamic> data) async {
    if (!_isMobilePlatform) {
      print('PushToTalk: Audio playback only available on mobile');
      return;
    }

    final base64Data = data['data'] as String?;
    final format = data['format'] as String? ?? 'aac';
    final durationMs = data['duration_ms'] as int? ?? 0;

    if (base64Data == null || base64Data.isEmpty) {
      print('PushToTalk: Received empty audio data');
      return;
    }

    print('PushToTalk: Received audio message (${base64Data.length} chars, $format, ${durationMs}ms)');

    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format == 'wav' ? 'wav' : 'm4a';
      final filePath = '${tempDir.path}/robot_audio_$timestamp.$extension';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      print('PushToTalk: Saved audio to $filePath (${bytes.length} bytes)');

      // Play the audio
      await _playAudioFile(filePath);
    } catch (e) {
      print('PushToTalk: Failed to handle incoming audio: $e');
      state = state.copyWith(
        state: PttState.idle,
        error: 'Failed to play audio from robot',
      );
    }
  }

  /// Play an audio file
  Future<void> _playAudioFile(String filePath) async {
    if (_audioPlayer == null) {
      await _initPlayer();
    }

    try {
      state = state.copyWith(state: PttState.playing);

      await _audioPlayer!.play(DeviceFileSource(filePath));
      print('PushToTalk: Playing audio');
    } catch (e) {
      print('PushToTalk: Failed to play audio: $e');
      state = state.copyWith(
        state: PttState.idle,
        error: 'Failed to play audio',
      );
    }
  }

  @override
  void dispose() {
    _audioMessageSubscription?.cancel();
    _progressTimer?.cancel();
    _recorder?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Check microphone permission
  Future<bool> _hasPermission() async {
    if (!_isMobilePlatform) return false;
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> _requestPermission() async {
    if (!_isMobilePlatform) return false;

    print('PushToTalk: Requesting microphone permission...');
    final status = await Permission.microphone.request();
    print('PushToTalk: Permission result: $status');

    if (status.isPermanentlyDenied) {
      state = state.copyWith(
        error: 'Microphone permission denied. Please enable in Settings.',
      );
      return false;
    }

    return status.isGranted;
  }

  /// Start recording - Full implementation for mobile
  Future<bool> startRecording() async {
    // Platform check
    if (!_isMobilePlatform) {
      state = state.copyWith(
        error: 'Recording only available on mobile (iOS/Android)',
      );
      print('PushToTalk: Recording only available on mobile');
      return false;
    }

    // Permission check
    if (!await _hasPermission()) {
      final granted = await _requestPermission();
      if (!granted) {
        state = state.copyWith(error: 'Microphone permission denied');
        return false;
      }
    }

    // Ensure recorder is initialized
    if (_recorder == null) {
      await _initRecorder();
    }

    // Check if recorder is available
    final hasRecorder = await _recorder!.hasPermission();
    if (!hasRecorder) {
      state = state.copyWith(error: 'Recorder not available');
      print('PushToTalk: Recorder not available');
      return false;
    }

    try {
      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/ptt_$timestamp.m4a';

      // Configure and start recording
      // AAC format, 16kHz sample rate, mono channel
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: _currentRecordingPath!,
      );

      _recordingStartTime = DateTime.now();

      // Start progress timer
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!state.isRecording) {
          _progressTimer?.cancel();
          return;
        }

        final elapsed =
            DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        final progress = elapsed / maxRecordingDurationMs;

        state = state.copyWith(
          recordingProgress: progress.clamp(0.0, 1.0),
          recordingDurationMs: elapsed,
        );

        // Auto-stop at max duration
        if (elapsed >= maxRecordingDurationMs) {
          print('PushToTalk: Max recording duration reached');
          stopRecordingAndSend();
        }
      });

      state = state.copyWith(
        state: PttState.recording,
        recordingProgress: 0,
        recordingDurationMs: 0,
        error: null,
      );

      print('PushToTalk: Started recording at $_currentRecordingPath');
      return true;
    } catch (e) {
      print('PushToTalk: Failed to start recording: $e');
      state = state.copyWith(error: 'Failed to start recording: $e');
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }

  /// Stop recording and send to robot
  Future<bool> stopRecordingAndSend() async {
    _progressTimer?.cancel();

    if (!state.isRecording || _recorder == null) {
      return false;
    }

    try {
      // Stop recording
      final path = await _recorder!.stop();

      if (path == null || path.isEmpty) {
        print('PushToTalk: Recording returned null path');
        state = state.copyWith(
          state: PttState.idle,
          error: 'Recording failed - no audio captured',
        );
        return false;
      }

      // Calculate duration
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      // Verify file exists
      final file = File(path);
      if (!await file.exists()) {
        print('PushToTalk: Recording file does not exist at $path');
        state = state.copyWith(
          state: PttState.idle,
          error: 'Recording failed - file not found',
        );
        return false;
      }

      final fileSize = await file.length();
      print('PushToTalk: Recording complete: $path ($fileSize bytes, ${durationMs}ms)');

      // Update state to sending
      state = state.copyWith(state: PttState.sending);

      // Read file and encode as base64
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Send via WebSocket
      WebSocketClient.instance.sendAudioMessage(base64Data, 'aac', durationMs);

      print('PushToTalk: Sent audio message to robot');

      // Clean up temp file
      try {
        await file.delete();
      } catch (e) {
        print('PushToTalk: Failed to delete temp file: $e');
      }

      // Return to idle
      state = state.copyWith(
        state: PttState.idle,
        recordingProgress: 0,
        recordingDurationMs: 0,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;

      return true;
    } catch (e) {
      print('PushToTalk: Failed to stop recording and send: $e');
      state = state.copyWith(
        state: PttState.idle,
        error: 'Failed to send audio: $e',
      );
      return false;
    }
  }

  /// Cancel recording without sending
  Future<void> cancelRecording() async {
    _progressTimer?.cancel();

    if (_recorder != null && state.isRecording) {
      try {
        await _recorder!.stop();
      } catch (e) {
        print('PushToTalk: Error stopping recorder: $e');
      }
    }

    // Clean up temp file if exists
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('PushToTalk: Error deleting temp file: $e');
      }
    }

    state = state.copyWith(
      state: PttState.idle,
      recordingProgress: 0,
      recordingDurationMs: 0,
    );

    _currentRecordingPath = null;
    _recordingStartTime = null;

    print('PushToTalk: Recording cancelled');
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

  /// Stop playback
  Future<void> stopPlayback() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (e) {
        print('PushToTalk: Error stopping playback: $e');
      }
    }
    state = state.copyWith(state: PttState.idle);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
