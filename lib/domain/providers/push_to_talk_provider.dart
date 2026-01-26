import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/remote_logger.dart';

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
    return false;
  }
}

/// Provider for push-to-talk state
final pushToTalkProvider =
    StateNotifierProvider<PushToTalkNotifier, PttStateData>((ref) {
  return PushToTalkNotifier();
});

/// Push-to-talk notifier using record package
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
      _initPlayer();
    }
    print('PushToTalk: Initialized (isMobile=$_isMobilePlatform)');
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      print('PushToTalk: Playback complete');
      if (state.state == PttState.playing) {
        state = state.copyWith(state: PttState.idle);
      }
    });
  }

  void _setupAudioListener() {
    _audioMessageSubscription =
        WebSocketClient.instance.eventStream.listen((event) {
      if (event.type == 'audio_message') {
        _handleIncomingAudio(event.data);
      }
    });
  }

  Future<void> _handleIncomingAudio(Map<String, dynamic> data) async {
    if (!_isMobilePlatform) return;

    final base64Data = data['data'] as String?;
    final format = data['format'] as String? ?? 'aac';
    final durationMs = data['duration_ms'] as int? ?? 0;

    if (base64Data == null || base64Data.isEmpty) return;

    print('PushToTalk: Received audio (${base64Data.length} chars, $format, ${durationMs}ms)');

    try {
      final bytes = base64Decode(base64Data);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format == 'wav' ? 'wav' : 'm4a';
      final filePath = '${tempDir.path}/robot_audio_$timestamp.$extension';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await _playAudioFile(filePath);
    } catch (e) {
      print('PushToTalk: Failed to handle incoming audio: $e');
      state = state.copyWith(state: PttState.idle, error: 'Failed to play audio');
    }
  }

  Future<void> _playAudioFile(String filePath) async {
    if (_audioPlayer == null) await _initPlayer();

    try {
      state = state.copyWith(state: PttState.playing);
      await _audioPlayer!.play(DeviceFileSource(filePath));
    } catch (e) {
      print('PushToTalk: Failed to play audio: $e');
      state = state.copyWith(state: PttState.idle, error: 'Failed to play audio');
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

  /// Start recording
  Future<bool> startRecording() async {
    rlog('PTT', 'startRecording() called');
    rlog('PTT', 'Platform.isIOS=${Platform.isIOS}, Platform.isAndroid=${Platform.isAndroid}');

    final isMobile = Platform.isIOS || Platform.isAndroid;
    rlog('PTT', 'isMobile=$isMobile');

    if (!isMobile) {
      rlog('PTT', 'FAILED - not on mobile platform');
      state = state.copyWith(error: 'Recording only available on iOS/Android');
      return false;
    }

    try {
      rlog('PTT', 'Creating AudioRecorder...');
      _recorder ??= AudioRecorder();

      rlog('PTT', 'Checking permission...');
      final hasPermission = await _recorder!.hasPermission();
      rlog('PTT', 'hasPermission=$hasPermission');

      if (!hasPermission) {
        rlog('PTT', 'FAILED - permission denied');
        state = state.copyWith(error: 'Microphone permission denied');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/ptt_$timestamp.m4a';
      rlog('PTT', 'Recording to $_currentRecordingPath');

      rlog('PTT', 'Starting recorder (AAC, 16kHz, mono)...');
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      rlog('PTT', 'Recorder started OK');

      _recordingStartTime = DateTime.now();

      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!state.isRecording) {
          _progressTimer?.cancel();
          return;
        }

        final elapsed = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        final progress = elapsed / maxRecordingDurationMs;

        state = state.copyWith(
          recordingProgress: progress.clamp(0.0, 1.0),
          recordingDurationMs: elapsed,
        );

        if (elapsed >= maxRecordingDurationMs) {
          rlog('PTT', 'Max duration reached');
          stopRecordingAndSend();
        }
      });

      state = state.copyWith(
        state: PttState.recording,
        recordingProgress: 0,
        recordingDurationMs: 0,
        error: null,
      );

      rlog('PTT', 'Recording started successfully');
      return true;
    } catch (e) {
      rlog('PTT', 'ERROR starting recording: $e');
      state = state.copyWith(error: 'Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and send
  Future<bool> stopRecordingAndSend() async {
    _progressTimer?.cancel();

    if (!state.isRecording || _recorder == null) {
      rlog('PTT', 'stopRecordingAndSend: not recording or no recorder');
      return false;
    }

    try {
      rlog('PTT', 'Stopping recorder...');
      final path = await _recorder!.stop();
      rlog('PTT', 'Recorder stopped, path=$path');

      if (path == null || path.isEmpty) {
        rlog('PTT', 'ERROR: Empty path returned');
        state = state.copyWith(state: PttState.idle, error: 'Recording failed');
        return false;
      }

      final file = File(path);
      if (!await file.exists()) {
        rlog('PTT', 'ERROR: File does not exist at $path');
        state = state.copyWith(state: PttState.idle, error: 'Recording file not found');
        return false;
      }

      final fileSize = await file.length();
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      rlog('PTT', 'File size=$fileSize bytes, duration=${durationMs}ms');

      state = state.copyWith(state: PttState.sending);

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      rlog('PTT', 'Sending audio (${base64Data.length} chars base64)...');
      WebSocketClient.instance.sendAudioMessage(base64Data, 'aac', durationMs);
      rlog('PTT', 'Audio sent to robot');

      try { await file.delete(); } catch (_) {}

      state = state.copyWith(
        state: PttState.idle,
        recordingProgress: 0,
        recordingDurationMs: 0,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;

      return true;
    } catch (e) {
      rlog('PTT', 'ERROR stop/send: $e');
      state = state.copyWith(state: PttState.idle, error: 'Failed to send audio: $e');
      return false;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    _progressTimer?.cancel();

    if (_recorder != null && state.isRecording) {
      try { await _recorder!.stop(); } catch (_) {}
    }

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
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

  /// Request audio from robot
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    print('PushToTalk: Requesting ${durationSeconds}s audio');
    state = state.copyWith(state: PttState.requesting, error: null);
    WebSocketClient.instance.requestAudioFromRobot(durationSeconds);

    Future.delayed(Duration(seconds: durationSeconds + 2), () {
      if (state.state == PttState.requesting) {
        state = state.copyWith(state: PttState.idle, error: 'No audio received');
      }
    });
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    try { await _audioPlayer?.stop(); } catch (_) {}
    state = state.copyWith(state: PttState.idle);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Run diagnostics
  Future<String> runDiagnostics() async {
    final results = StringBuffer();
    results.writeln('=== RECORDING DIAGNOSTICS ===');
    results.writeln('Platform.isIOS: ${Platform.isIOS}');
    results.writeln('Platform.isAndroid: ${Platform.isAndroid}');
    results.writeln('_isMobilePlatform: $_isMobilePlatform');

    try {
      _recorder ??= AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      results.writeln('hasPermission: $hasPermission');

      if (hasPermission) {
        results.writeln('Attempting test recording...');
        final tempDir = await getTemporaryDirectory();
        final testPath = '${tempDir.path}/test_recording.m4a';

        await _recorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
          path: testPath,
        );
        results.writeln('Recording started');

        await Future.delayed(const Duration(seconds: 1));

        final path = await _recorder!.stop();
        results.writeln('Recording stopped: $path');

        if (path != null) {
          final file = File(path);
          final exists = await file.exists();
          results.writeln('File exists: $exists');
          if (exists) {
            final size = await file.length();
            results.writeln('File size: $size bytes');
            results.writeln('TEST: ${size > 0 ? "SUCCESS" : "FAILED (empty file)"}');
            await file.delete();
          }
        }
      }
    } catch (e) {
      results.writeln('ERROR: $e');
    }

    results.writeln('=== END DIAGNOSTICS ===');
    return results.toString();
  }
}
