import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Check if we're on a mobile platform (uses print, not rprint, for safe early init)
bool get _isMobilePlatform {
  try {
    final isIOS = Platform.isIOS;
    final isAndroid = Platform.isAndroid;
    // Use print() not rprint() - this runs during early init before WebSocket is ready
    print('PushToTalk: Platform check - isIOS=$isIOS, isAndroid=$isAndroid');
    return isIOS || isAndroid;
  } catch (e) {
    print('PushToTalk: Platform check failed (web?): $e');
    return false; // Web platform
  }
}

/// Provider for push-to-talk state
final pushToTalkProvider =
    StateNotifierProvider<PushToTalkNotifier, PttStateData>((ref) {
  return PushToTalkNotifier();
});

/// Provider to run recording diagnostics
final recordingDiagnosticsProvider = FutureProvider<String>((ref) async {
  final notifier = ref.read(pushToTalkProvider.notifier);
  return notifier.runDiagnostics();
});

/// Push-to-talk notifier - Full implementation for mobile, stubbed for desktop
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  StreamSubscription? _audioMessageSubscription;

  // Recording
  FlutterSoundRecorder? _recorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;
  bool _isRecorderInitialized = false;

  // Playback
  AudioPlayer? _audioPlayer;

  // Max recording duration (30 seconds)
  static const int maxRecordingDurationMs = 30000;

  PushToTalkNotifier() : super(const PttStateData()) {
    _setupAudioListener();
    // Don't initialize recorder in constructor - do it lazily when needed
    // This prevents crashes during app startup
    if (_isMobilePlatform) {
      _initPlayer();
    }
  }

  Future<void> _initRecorder() async {
    print('PushToTalk: _initRecorder() called');

    try {
      print('PushToTalk: Creating FlutterSoundRecorder...');
      _recorder = FlutterSoundRecorder();
      print('PushToTalk: FlutterSoundRecorder created');
    } catch (e) {
      print('PushToTalk: FAILED to create FlutterSoundRecorder: $e');
      _isRecorderInitialized = false;
      return;
    }

    try {
      print('PushToTalk: Calling openRecorder()...');
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;
      print('PushToTalk: Recorder initialized successfully');
    } catch (e) {
      print('PushToTalk: FAILED to openRecorder(): $e');
      _isRecorderInitialized = false;
    }
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      rprint('PushToTalk: Playback complete');
      if (state.state == PttState.playing) {
        state = state.copyWith(state: PttState.idle);
      }
    });
    rprint('PushToTalk: Player initialized');
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
      rprint('PushToTalk: Audio playback only available on mobile');
      return;
    }

    final base64Data = data['data'] as String?;
    final format = data['format'] as String? ?? 'aac';
    final durationMs = data['duration_ms'] as int? ?? 0;

    if (base64Data == null || base64Data.isEmpty) {
      rprint('PushToTalk: Received empty audio data');
      return;
    }

    rprint('PushToTalk: Received audio message (${base64Data.length} chars, $format, ${durationMs}ms)');

    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format == 'wav' ? 'wav' : 'aac';
      final filePath = '${tempDir.path}/robot_audio_$timestamp.$extension';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      rprint('PushToTalk: Saved audio to $filePath (${bytes.length} bytes)');

      // Play the audio
      await _playAudioFile(filePath);
    } catch (e) {
      rprint('PushToTalk: Failed to handle incoming audio: $e');
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
      rprint('PushToTalk: Playing audio');
    } catch (e) {
      rprint('PushToTalk: Failed to play audio: $e');
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
    if (_recorder != null && _isRecorderInitialized) {
      _recorder!.closeRecorder();
    }
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

    rprint('PushToTalk: Requesting microphone permission...');
    final status = await Permission.microphone.request();
    rprint('PushToTalk: Permission result: $status');

    if (status.isPermanentlyDenied) {
      state = state.copyWith(
        error: 'Microphone permission denied. Please enable in Settings.',
      );
      return false;
    }

    return status.isGranted;
  }

  /// Run a diagnostic test of recording capability
  Future<String> runDiagnostics() async {
    final results = StringBuffer();
    results.writeln('=== RECORDING DIAGNOSTICS ===');
    results.writeln('Time: ${DateTime.now().toIso8601String()}');

    // Platform info
    try {
      results.writeln('Platform.isIOS: ${Platform.isIOS}');
      results.writeln('Platform.isAndroid: ${Platform.isAndroid}');
      results.writeln('Platform.operatingSystem: ${Platform.operatingSystem}');
      results.writeln('Platform.operatingSystemVersion: ${Platform.operatingSystemVersion}');
    } catch (e) {
      results.writeln('Platform check ERROR: $e');
    }

    results.writeln('_isMobilePlatform: $_isMobilePlatform');

    // Permission check
    try {
      final status = await Permission.microphone.status;
      results.writeln('Microphone permission: $status');
    } catch (e) {
      results.writeln('Permission check ERROR: $e');
    }

    // Recorder state
    results.writeln('_recorder: ${_recorder != null ? "exists" : "null"}');
    results.writeln('_isRecorderInitialized: $_isRecorderInitialized');

    if (_recorder != null) {
      try {
        results.writeln('_recorder.isRecording: ${_recorder!.isRecording}');
        results.writeln('_recorder.isStopped: ${_recorder!.isStopped}');
      } catch (e) {
        results.writeln('Recorder state check ERROR: $e');
      }
    }

    // Try to initialize recorder if not done
    if (!_isRecorderInitialized) {
      results.writeln('Attempting to initialize recorder...');
      try {
        _recorder = FlutterSoundRecorder();
        results.writeln('FlutterSoundRecorder created');
        await _recorder!.openRecorder();
        _isRecorderInitialized = true;
        results.writeln('openRecorder() SUCCESS');
      } catch (e, stack) {
        results.writeln('openRecorder() FAILED: $e');
        results.writeln('Stack: $stack');
      }
    }

    // Try a test recording
    if (_isRecorderInitialized) {
      results.writeln('Attempting 1 second test recording...');
      try {
        final tempDir = await getTemporaryDirectory();
        final testPath = '${tempDir.path}/diagnostic_test.aac';
        results.writeln('Test path: $testPath');

        await _recorder!.startRecorder(
          toFile: testPath,
          codec: Codec.aacADTS,
          sampleRate: 16000,
          numChannels: 1,
        );
        results.writeln('startRecorder() SUCCESS');

        await Future.delayed(const Duration(seconds: 1));

        final path = await _recorder!.stopRecorder();
        results.writeln('stopRecorder() returned: $path');

        if (path != null) {
          final file = File(path);
          final exists = await file.exists();
          results.writeln('File exists: $exists');
          if (exists) {
            final size = await file.length();
            results.writeln('File size: $size bytes');
            await file.delete();
            results.writeln('Test file deleted');
          }
        }

        results.writeln('TEST RECORDING: SUCCESS');
      } catch (e, stack) {
        results.writeln('TEST RECORDING FAILED: $e');
        results.writeln('Stack: $stack');
      }
    }

    results.writeln('=== END DIAGNOSTICS ===');

    final output = results.toString();
    rprint(output);
    return output;
  }

  /// Start recording - Full implementation for mobile
  Future<bool> startRecording() async {
    rprint('PushToTalk: ===== startRecording() CALLED =====');

    // Platform check
    rprint('PushToTalk: Checking platform...');
    final isMobile = _isMobilePlatform;
    rprint('PushToTalk: isMobile = $isMobile');

    if (!isMobile) {
      final errorMsg = 'Recording only available on mobile (iOS/Android)';
      rprint('PushToTalk: ERROR - $errorMsg');
      state = state.copyWith(error: errorMsg);
      return false;
    }

    // Permission check
    rprint('PushToTalk: Checking microphone permission...');
    final hasPerm = await _hasPermission();
    rprint('PushToTalk: hasPermission = $hasPerm');

    if (!hasPerm) {
      rprint('PushToTalk: Requesting permission...');
      final granted = await _requestPermission();
      rprint('PushToTalk: Permission granted = $granted');
      if (!granted) {
        state = state.copyWith(error: 'Microphone permission denied');
        return false;
      }
    }

    // Ensure recorder is initialized
    rprint('PushToTalk: Checking recorder state - recorder=${_recorder != null}, initialized=$_isRecorderInitialized');

    if (_recorder == null || !_isRecorderInitialized) {
      rprint('PushToTalk: Recorder not ready, initializing...');
      await _initRecorder();
      rprint('PushToTalk: After init - recorder=${_recorder != null}, initialized=$_isRecorderInitialized');

      if (!_isRecorderInitialized) {
        final errorMsg = 'Recorder not available - initialization failed';
        rprint('PushToTalk: ERROR - $errorMsg');
        state = state.copyWith(error: errorMsg);
        return false;
      }
    }

    try {
      // Get temp directory for recording
      rprint('PushToTalk: Getting temp directory...');
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/ptt_$timestamp.aac';
      rprint('PushToTalk: Recording path: $_currentRecordingPath');

      // Start recording - AAC format, 16kHz sample rate, mono channel
      rprint('PushToTalk: Calling startRecorder()...');
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
      );
      rprint('PushToTalk: startRecorder() completed successfully');

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
          rprint('PushToTalk: Max recording duration reached');
          stopRecordingAndSend();
        }
      });

      state = state.copyWith(
        state: PttState.recording,
        recordingProgress: 0,
        recordingDurationMs: 0,
        error: null,
      );

      rprint('PushToTalk: Recording STARTED at $_currentRecordingPath');
      return true;
    } catch (e, stack) {
      rprint('PushToTalk: EXCEPTION in startRecording: $e');
      rprint('PushToTalk: Stack: $stack');
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
      final path = await _recorder!.stopRecorder();

      if (path == null || path.isEmpty) {
        rprint('PushToTalk: Recording returned null path');
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
        rprint('PushToTalk: Recording file does not exist at $path');
        state = state.copyWith(
          state: PttState.idle,
          error: 'Recording failed - file not found',
        );
        return false;
      }

      final fileSize = await file.length();
      rprint('PushToTalk: Recording complete: $path ($fileSize bytes, ${durationMs}ms)');

      // Update state to sending
      state = state.copyWith(state: PttState.sending);

      // Read file and encode as base64
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Send via WebSocket
      WebSocketClient.instance.sendAudioMessage(base64Data, 'aac', durationMs);

      rprint('PushToTalk: Sent audio message to robot');

      // Clean up temp file
      try {
        await file.delete();
      } catch (e) {
        rprint('PushToTalk: Failed to delete temp file: $e');
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
      rprint('PushToTalk: Failed to stop recording and send: $e');
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
        await _recorder!.stopRecorder();
      } catch (e) {
        rprint('PushToTalk: Error stopping recorder: $e');
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
        rprint('PushToTalk: Error deleting temp file: $e');
      }
    }

    state = state.copyWith(
      state: PttState.idle,
      recordingProgress: 0,
      recordingDurationMs: 0,
    );

    _currentRecordingPath = null;
    _recordingStartTime = null;

    rprint('PushToTalk: Recording cancelled');
  }

  /// Request audio from robot (listen button)
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    rprint('PushToTalk: Requesting ${durationSeconds}s audio from robot');

    state = state.copyWith(state: PttState.requesting, error: null);
    WebSocketClient.instance.requestAudioFromRobot(durationSeconds);

    // Timeout after duration + 2 seconds
    Future.delayed(Duration(seconds: durationSeconds + 2), () {
      if (state.state == PttState.requesting) {
        rprint('PushToTalk: Audio request timed out');
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
        rprint('PushToTalk: Error stopping playback: $e');
      }
    }
    state = state.copyWith(state: PttState.idle);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
