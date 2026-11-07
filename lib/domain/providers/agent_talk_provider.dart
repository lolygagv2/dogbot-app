import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/agent_api.dart';
import '../../data/models/notification_event.dart' show attachmentBaseUrl;
import '../../l10n/l10n.dart';
import 'agent_transcript_provider.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';
import 'device_provider.dart';
import 'dog_profiles_provider.dart';
import 'l10n_provider.dart';
import 'settings_provider.dart';

enum AgentTalkPhase { idle, recording, sending, playingRobot, playingPhone }

/// Hold-to-talk state for "Talk to WIM-Z" on the dog profile.
class AgentTalkState {
  final AgentTalkPhase phase;
  final int elapsedMs;
  final String? textIn; // last transcription of the owner
  final String? textOut; // last agent reply
  final List<String> refused;
  final List<String> toolsUsed;
  final String? error;

  /// Relay has no voice-agent route (404) — hide the button's promise.
  final bool unsupported;

  /// When the last reply arrived (Home banner lingers briefly after it).
  final DateTime? replyAt;

  const AgentTalkState({
    this.phase = AgentTalkPhase.idle,
    this.elapsedMs = 0,
    this.textIn,
    this.textOut,
    this.refused = const [],
    this.toolsUsed = const [],
    this.error,
    this.unsupported = false,
    this.replyAt,
  });

  bool get isRecording => phase == AgentTalkPhase.recording;
  bool get isBusy => phase == AgentTalkPhase.sending;

  AgentTalkState copyWith({
    AgentTalkPhase? phase,
    int? elapsedMs,
    String? textIn,
    String? textOut,
    List<String>? refused,
    List<String>? toolsUsed,
    String? error,
    bool clearError = false,
    bool? unsupported,
    DateTime? replyAt,
  }) =>
      AgentTalkState(
        phase: phase ?? this.phase,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        textIn: textIn ?? this.textIn,
        textOut: textOut ?? this.textOut,
        refused: refused ?? this.refused,
        toolsUsed: toolsUsed ?? this.toolsUsed,
        error: clearError ? null : (error ?? this.error),
        unsupported: unsupported ?? this.unsupported,
        replyAt: replyAt ?? this.replyAt,
      );
}

final agentTalkProvider =
    StateNotifierProvider<AgentTalkNotifier, AgentTalkState>(
        (ref) => AgentTalkNotifier(ref));

/// Records one utterance (16 kHz mono WAV, ≤ 30 s), POSTs it to the relay
/// voice agent with the user JWT + dog_id, puts text_in / text_out on the
/// agent transcript, and plays the reply on the robot (`play_sound`
/// {url, clip_id, kind: tts}) — or on the phone when the robot is offline.
class AgentTalkNotifier extends StateNotifier<AgentTalkState> {
  static const int maxMs = 30000; // relay limit
  static const int minMs = 600; // ignore accidental taps

  final Ref _ref;
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  StreamSubscription? _playerDone;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;

  AgentTalkNotifier(this._ref) : super(const AgentTalkState());

  AppLocalizations get _l => _ref.read(l10nProvider);

  /// Begin recording. Returns false (with [state.error] set) when it can't.
  Future<bool> startRecording() async {
    if (state.isRecording || state.isBusy) return false;
    if (_ref.read(settingsProvider).localModeEnabled) {
      return _fail(_l.talkErrLocal);
    }
    if (_ref.read(authProvider).token == null) return _fail(_l.talkErrSignedOut);
    if (_ref.read(selectedDogProvider) == null) return _fail(_l.aiErrNoDog);

    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) return _fail(_l.talkErrMic);
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/agent_utterance_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
      _startedAt = DateTime.now();
      state = state.copyWith(
          phase: AgentTalkPhase.recording, elapsedMs: 0, clearError: true);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _startedAt == null) return;
        final ms = DateTime.now().difference(_startedAt!).inMilliseconds;
        state = state.copyWith(elapsedMs: ms);
        if (ms >= maxMs) stopAndSend();
      });
      connTrace('agent-talk', 'recording started');
      return true;
    } catch (e) {
      connTrace('agent-talk-error', 'start: $e');
      return _fail(_l.talkErrFailed('$e'));
    }
  }

  /// Stop recording and send the clip. No-op unless recording.
  Future<void> stopAndSend() async {
    if (!state.isRecording) return;
    _ticker?.cancel();
    _ticker = null;
    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    String? path;
    try {
      path = await _recorder!.stop();
    } catch (e) {
      connTrace('agent-talk-error', 'stop: $e');
    }
    path ??= _path;
    if (!mounted) return;
    if (path == null || elapsed < minMs) {
      _deleteQuietly(path);
      state = state.copyWith(phase: AgentTalkPhase.idle, error: _l.talkTooShort);
      return;
    }

    state = state.copyWith(phase: AgentTalkPhase.sending, clearError: true);
    final token = _ref.read(authProvider).token;
    final dog = _ref.read(selectedDogProvider);
    if (token == null || dog == null) {
      _deleteQuietly(path);
      state = state.copyWith(
          phase: AgentTalkPhase.idle,
          error: token == null ? _l.talkErrSignedOut : _l.aiErrNoDog);
      return;
    }

    final result = await _ref
        .read(agentApiProvider)
        .utterance(token: token, dogId: dog.id, filePath: path);
    _deleteQuietly(path);
    if (!mounted) return;

    if (result.unsupported) {
      state = state.copyWith(
          phase: AgentTalkPhase.idle,
          unsupported: true,
          error: _l.talkUnsupported);
      return;
    }
    final reply = result.reply;
    if (reply == null) {
      state = state.copyWith(
          phase: AgentTalkPhase.idle,
          error: _l.talkErrFailed(result.error ?? '?'));
      return;
    }

    // Transcript: the relay also broadcasts agent_transcript frames for
    // these two lines; the transcript provider de-duplicates by text.
    final transcript = _ref.read(agentTranscriptProvider.notifier);
    if (reply.textIn != null) {
      transcript.appendLocal(_l.talkYou, reply.textIn!, role: 'user');
    }
    if (reply.textOut != null) {
      transcript.appendLocal('WIM-Z', reply.textOut!, role: 'agent');
    }

    state = state.copyWith(
      textIn: reply.textIn,
      textOut: reply.textOut,
      refused: reply.refused,
      toolsUsed: reply.toolsUsed,
      phase: AgentTalkPhase.idle,
      clearError: true,
      replyAt: DateTime.now(),
    );

    final url = _absolutize(reply.audioUrl);
    if (url == null) return;
    await _play(url, reply.clipId);
  }

  Future<void> _play(String url, String? clipId) async {
    final conn = _ref.read(connectionProvider);
    final robotOnline = !conn.isDemoMode &&
        conn.isRobotOnline &&
        _ref.read(hasSelectedDeviceProvider);
    if (robotOnline) {
      // Same frame the relay sends the robot for agent speech
      // (robot brief 2026-11-06 §4: play_sound {url, clip_id, kind: "tts"}).
      _ref.read(websocketClientProvider).sendCommand('play_sound', {
        'url': url,
        if (clipId != null) 'clip_id': clipId,
        'kind': 'tts',
        'source': 'app',
      });
      connTrace('agent-talk', 'reply → robot play_sound');
      state = state.copyWith(phase: AgentTalkPhase.playingRobot);
      // The robot doesn't tell us when it finished; show the state briefly.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && state.phase == AgentTalkPhase.playingRobot) {
          state = state.copyWith(phase: AgentTalkPhase.idle);
        }
      });
      return;
    }
    try {
      _player ??= AudioPlayer();
      _playerDone ??= _player!.onPlayerComplete.listen((_) {
        if (mounted && state.phase == AgentTalkPhase.playingPhone) {
          state = state.copyWith(phase: AgentTalkPhase.idle);
        }
      });
      await _player!.stop();
      await _player!.play(UrlSource(url));
      connTrace('agent-talk', 'reply → phone speaker (robot offline)');
      state = state.copyWith(phase: AgentTalkPhase.playingPhone);
    } catch (e) {
      connTrace('agent-talk-error', 'phone playback: $e');
      state = state.copyWith(
          phase: AgentTalkPhase.idle, error: _l.talkErrFailed('$e'));
    }
  }

  /// Abort a recording in progress without sending.
  Future<void> cancel() async {
    _ticker?.cancel();
    _ticker = null;
    if (state.isRecording) {
      try {
        final p = await _recorder?.stop();
        _deleteQuietly(p ?? _path);
      } catch (_) {}
    }
    if (mounted) state = state.copyWith(phase: AgentTalkPhase.idle);
  }

  bool _fail(String message) {
    state = state.copyWith(phase: AgentTalkPhase.idle, error: message);
    return false;
  }

  static String? _absolutize(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = attachmentBaseUrl.endsWith('/')
        ? attachmentBaseUrl.substring(0, attachmentBaseUrl.length - 1)
        : attachmentBaseUrl;
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  static void _deleteQuietly(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _playerDone?.cancel();
    _player?.dispose();
    _recorder?.dispose();
    super.dispose();
  }
}
