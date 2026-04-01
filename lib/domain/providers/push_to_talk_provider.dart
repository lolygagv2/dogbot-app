import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/remote_logger.dart';
import 'webrtc_provider.dart';

/// Push-to-talk state
enum PttState {
  idle,
  recording,
  sending,
  sent, // brief confirmation state before returning to idle
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
  bool get isSent => state == PttState.sent;
  bool get isBusy => state != PttState.idle && state != PttState.sent;
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
  return PushToTalkNotifier(ref);
});

/// Push-to-talk notifier using record package
class PushToTalkNotifier extends StateNotifier<PttStateData> {
  final Ref _ref;
  StreamSubscription? _audioMessageSubscription;

  // Recording
  AudioRecorder? _recorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;

  // Playback
  AudioPlayer? _audioPlayer;

  // WebRTC audio coordination
  bool _webrtcWasMuted = true;

  // Max recording duration (5 seconds — tap toggle style)
  static const int maxRecordingDurationMs = 5000;

  PushToTalkNotifier(this._ref) : super(const PttStateData()) {
    _setupAudioListener();
    if (_isMobilePlatform) {
      _initPlayer();
    }
    rlog('PTT_START', 'Initialized (isMobile=$_isMobilePlatform)');
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      rlog('PTT_RECORDING', 'Playback complete');
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

    rlog('PTT_RECORDING', 'Received audio (${base64Data.length} chars, $format, ${durationMs}ms)');

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
      rlog('PTT_ERROR', 'Failed to handle incoming audio: $e');
      state = state.copyWith(state: PttState.idle, error: 'Failed to play audio');
    }
  }

  Future<void> _playAudioFile(String filePath) async {
    if (_audioPlayer == null) await _initPlayer();

    try {
      state = state.copyWith(state: PttState.playing);
      await _audioPlayer!.play(DeviceFileSource(filePath));
    } catch (e) {
      rlog('PTT_ERROR', 'Failed to play audio: $e');
      state = state.copyWith(state: PttState.idle, error: 'Failed to play audio');
    }
  }

  /// Mute WebRTC audio track before recording to avoid iOS audio session conflict.
  void _muteWebRTCAudio() {
    try {
      final webrtcState = _ref.read(webrtcProvider);
      _webrtcWasMuted = webrtcState.isAudioMuted;
      if (!_webrtcWasMuted) {
        _ref.read(webrtcProvider.notifier).setAudioTrackEnabled(false);
        rlog('PTT_START', 'WebRTC audio muted for PTT (was unmuted)');
      } else {
        rlog('PTT_START', 'WebRTC audio already muted, no change needed');
      }
    } catch (e) {
      rlog('PTT_ERROR', 'Failed to mute WebRTC audio: $e');
      // Continue anyway — recording may still work
    }
  }

  /// Restore WebRTC audio track after recording completes.
  void _restoreWebRTCAudio() {
    try {
      if (!_webrtcWasMuted) {
        _ref.read(webrtcProvider.notifier).setAudioTrackEnabled(true);
        rlog('PTT_STOP', 'WebRTC audio restored (unmuted)');
      }
    } catch (e) {
      rlog('PTT_ERROR', 'Failed to restore WebRTC audio: $e');
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

  /// Toggle recording: tap to start, tap again to stop and send.
  Future<bool> toggleRecording() async {
    if (state.isRecording) {
      print('[PTT] Button released — stopping and sending');
      return stopRecordingAndSend();
    } else {
      print('[PTT] Button pressed — starting recording');
      return startRecording();
    }
  }

  /// Start recording
  Future<bool> startRecording() async {
    print('[PTT] startRecording() called — platform: iOS=${Platform.isIOS}, Android=${Platform.isAndroid}');
    rlog('PTT_START', 'startRecording() called');
    rlog('PTT_START', 'Platform.isIOS=${Platform.isIOS}, Platform.isAndroid=${Platform.isAndroid}');

    final isMobile = Platform.isIOS || Platform.isAndroid;

    if (!isMobile) {
      print('[PTT] ERROR: Not on mobile platform');
      rlog('PTT_ERROR', 'Not on mobile platform');
      state = state.copyWith(error: 'Recording only available on iOS/Android');
      return false;
    }

    // Check connection before recording — don't waste user's time
    if (WebSocketClient.instance.state != WsConnectionState.connected) {
      print('[PTT] ERROR: WebSocket not connected — cannot send voice');
      rlog('PTT_ERROR', 'WebSocket not connected');
      state = state.copyWith(error: 'Not connected — cannot send voice');
      return false;
    }

    try {
      // Create FRESH recorder each time to avoid stale state
      rlog('PTT_START', 'Creating fresh AudioRecorder...');
      _recorder?.dispose();
      _recorder = AudioRecorder();

      print('[PTT] Checking mic permission...');
      rlog('PTT_START', 'Checking permission...');
      final hasPermission = await _recorder!.hasPermission();
      rlog('PTT_START', 'hasPermission=$hasPermission');

      if (!hasPermission) {
        print('[PTT] ERROR: Microphone permission denied');
        rlog('PTT_ERROR', 'Permission denied');
        state = state.copyWith(error: 'Microphone permission denied');
        return false;
      }

      // Mute WebRTC audio to avoid iOS audio session conflict
      _muteWebRTCAudio();

      // On iOS, wait for audio session to settle after muting WebRTC
      if (Platform.isIOS && !_webrtcWasMuted) {
        rlog('PTT_START', 'iOS: waiting 200ms for audio session to settle');
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use WAV format - raw PCM always works on iOS (AAC was producing empty files)
      _currentRecordingPath = '${tempDir.path}/ptt_$timestamp.wav';
      rlog('PTT_START', 'Recording to $_currentRecordingPath');

      rlog('PTT_START', 'Starting recorder (WAV, 44100Hz, mono)...');
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      // Verify recording actually started
      final isActuallyRecording = await _recorder!.isRecording();
      if (!isActuallyRecording) {
        rlog('PTT_ERROR', 'Recorder.start() returned but isRecording=false');
        _restoreWebRTCAudio();
        state = state.copyWith(error: 'Recording failed to start');
        return false;
      }
      print('[PTT] Mic capture started — WAV 44100Hz mono');
      rlog('PTT_RECORDING', 'Recording confirmed active');

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
          rlog('PTT_RECORDING', 'Max duration (5s) reached, auto-stopping');
          stopRecordingAndSend();
        }
      });

      state = state.copyWith(
        state: PttState.recording,
        recordingProgress: 0,
        recordingDurationMs: 0,
        error: null,
      );

      print('[PTT] Recording started successfully');
      rlog('PTT_RECORDING', 'Recording started successfully');
      return true;
    } catch (e) {
      print('[PTT] ERROR: Failed to start recording: $e');
      rlog('PTT_ERROR', 'Starting recording: $e');
      _restoreWebRTCAudio();
      state = state.copyWith(error: 'Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and send
  Future<bool> stopRecordingAndSend() async {
    _progressTimer?.cancel();

    if (!state.isRecording || _recorder == null) {
      print('[PTT] stopRecordingAndSend: not recording or no recorder');
      rlog('PTT_STOP', 'stopRecordingAndSend: not recording or no recorder');
      return false;
    }

    final sendStartTime = DateTime.now();

    try {
      print('[PTT] Mic capture stopping...');
      rlog('PTT_STOP', 'Stopping recorder...');
      final path = await _recorder!.stop();
      print('[PTT] Mic capture stopped — path=$path');
      rlog('PTT_STOP', 'Recorder stopped, path=$path');

      if (path == null || path.isEmpty) {
        rlog('PTT_ERROR', 'Empty path returned from recorder');
        _restoreWebRTCAudio();
        state = state.copyWith(state: PttState.idle, error: 'Recording failed');
        return false;
      }

      // Wait for filesystem to flush the file
      await Future.delayed(const Duration(milliseconds: 500));

      final file = File(path);
      if (!await file.exists()) {
        rlog('PTT_ERROR', 'File does not exist at $path');
        _restoreWebRTCAudio();
        state = state.copyWith(state: PttState.idle, error: 'Recording file not found');
        return false;
      }

      final fileSize = await file.length();
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      rlog('PTT_STOP', 'File size=$fileSize bytes, duration=${durationMs}ms');

      // Check for empty recording (just container header, no audio data)
      if (fileSize < 100) {
        print('[PTT] ERROR: Recording empty ($fileSize bytes) — no audio captured');
        rlog('PTT_ERROR', 'File too small ($fileSize bytes) - recording is empty');
        _restoreWebRTCAudio();
        state = state.copyWith(state: PttState.idle, error: 'Recording was empty - no audio captured');
        try { await file.delete(); } catch (_) {}
        return false;
      }

      // Check WebSocket connection before sending
      if (WebSocketClient.instance.state != WsConnectionState.connected) {
        print('[PTT] ERROR: Connection dropped — cannot send audio');
        rlog('PTT_ERROR', 'WebSocket not connected, cannot send audio');
        _restoreWebRTCAudio();
        state = state.copyWith(state: PttState.idle, error: 'Not connected — voice message not sent');
        try { await file.delete(); } catch (_) {}
        return false;
      }

      state = state.copyWith(state: PttState.sending);

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      print('[PTT] Sending audio packet — ${bytes.length} bytes raw, ${base64Data.length} chars base64, duration=${durationMs}ms');
      rlog('PTT_SEND', 'Sending audio: ${bytes.length} bytes raw, ${base64Data.length} chars base64, format=wav');
      WebSocketClient.instance.sendAudioMessage(base64Data, 'wav', durationMs);
      final sendLatencyMs = DateTime.now().difference(sendStartTime).inMilliseconds;
      print('[PTT] Audio sent to robot — total send latency: ${sendLatencyMs}ms (includes stop+encode+transmit)');
      rlog('PTT_SEND', 'Audio sent to robot, send latency: ${sendLatencyMs}ms');

      _restoreWebRTCAudio();

      // Auto-listen: force-unmute for 5s so user hears robot's environment
      _ref.read(webrtcProvider.notifier).startAutoListen(const Duration(seconds: 5));

      try { await file.delete(); } catch (_) {}

      _currentRecordingPath = null;
      _recordingStartTime = null;

      // Show "Sent" confirmation briefly
      state = state.copyWith(
        state: PttState.sent,
        recordingProgress: 0,
        recordingDurationMs: 0,
      );

      // Return to idle after 1.5s
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && state.state == PttState.sent) {
          state = state.copyWith(state: PttState.idle);
        }
      });

      return true;
    } catch (e) {
      print('[PTT] ERROR: Send failed — $e');
      rlog('PTT_ERROR', 'Stop/send failed: $e');
      _restoreWebRTCAudio();
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

    _restoreWebRTCAudio();

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
    print('[PTT] Recording cancelled');
    rlog('PTT_CANCEL', 'Recording cancelled');
  }

  /// Request audio from robot
  void requestAudio({int durationSeconds = 5}) {
    if (state.isBusy) return;

    rlog('PTT_START', 'Requesting ${durationSeconds}s audio from robot');
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
      // Create fresh recorder for diagnostics
      final testRecorder = AudioRecorder();
      final hasPermission = await testRecorder.hasPermission();
      results.writeln('hasPermission: $hasPermission');

      if (hasPermission) {
        final tempDir = await getTemporaryDirectory();

        // Test WAV format (should always work)
        results.writeln('');
        results.writeln('--- WAV Test (44100Hz mono) ---');
        final wavPath = '${tempDir.path}/test_recording.wav';
        await testRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 44100, numChannels: 1),
          path: wavPath,
        );
        results.writeln('Recording started...');
        await Future.delayed(const Duration(seconds: 2));

        final wavResult = await testRecorder.stop();
        await Future.delayed(const Duration(milliseconds: 500));
        results.writeln('Recording stopped: $wavResult');

        if (wavResult != null) {
          final file = File(wavResult);
          final exists = await file.exists();
          results.writeln('File exists: $exists');
          if (exists) {
            final size = await file.length();
            results.writeln('File size: $size bytes');
            // 2 seconds of 44100Hz 16-bit mono WAV ≈ 176KB
            // Anything under 1000 bytes is just a header
            if (size > 1000) {
              results.writeln('WAV TEST: SUCCESS ($size bytes)');
            } else {
              results.writeln('WAV TEST: FAILED (only $size bytes - no audio data)');
            }
            await file.delete();
          }
        }

        // Also test AAC for comparison
        results.writeln('');
        results.writeln('--- AAC Test (44100Hz mono) ---');
        final aacRecorder = AudioRecorder();
        final aacPath = '${tempDir.path}/test_recording.m4a';
        try {
          await aacRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, numChannels: 1),
            path: aacPath,
          );
          results.writeln('AAC recording started...');
          await Future.delayed(const Duration(seconds: 2));

          final aacResult = await aacRecorder.stop();
          await Future.delayed(const Duration(milliseconds: 500));

          if (aacResult != null) {
            final aacFile = File(aacResult);
            if (await aacFile.exists()) {
              final aacSize = await aacFile.length();
              results.writeln('AAC file size: $aacSize bytes');
              if (aacSize > 100) {
                results.writeln('AAC TEST: SUCCESS ($aacSize bytes)');
              } else {
                results.writeln('AAC TEST: FAILED (only $aacSize bytes)');
              }
              await aacFile.delete();
            }
          }
        } catch (e) {
          results.writeln('AAC TEST: ERROR - $e');
        } finally {
          aacRecorder.dispose();
        }
      }

      testRecorder.dispose();
    } catch (e) {
      results.writeln('ERROR: $e');
    }

    results.writeln('');
    results.writeln('=== END DIAGNOSTICS ===');
    rlog('DIAG', results.toString());
    return results.toString();
  }
}
