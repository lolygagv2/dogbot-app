import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../../core/utils/time_utils.dart';

final agentApiProvider = Provider<AgentApi>((ref) {
  return AgentApi(ref.watch(dioClientProvider));
});

/// `POST /agent/utterance` reply (relay brief 2026-11-06 §6):
/// {text_in, text_out, audio_url, clip_id, expires_at, tools_used[], refused[]}
class AgentReply {
  final String? textIn;
  final String? textOut;
  final String? audioUrl; // mp3, expires in ~15 min; may be relative
  final String? clipId;
  final DateTime? expiresAt;
  final List<String> toolsUsed;
  final List<String> refused;

  const AgentReply({
    this.textIn,
    this.textOut,
    this.audioUrl,
    this.clipId,
    this.expiresAt,
    this.toolsUsed = const [],
    this.refused = const [],
  });

  static AgentReply fromJson(Map<String, dynamic> j) {
    DateTime? expires;
    final raw = j['expires_at'];
    if (raw is num) {
      expires = DateTime.fromMillisecondsSinceEpoch(
          (raw > 1e12 ? raw : raw * 1000).toInt(),
          isUtc: true);
    } else if (raw != null) {
      expires = tryParseServerTimestamp(raw.toString());
    }
    return AgentReply(
      textIn: _str(j['text_in']),
      textOut: _str(j['text_out'] ?? j['text']),
      audioUrl: _str(j['audio_url']),
      clipId: _str(j['clip_id']),
      expiresAt: expires,
      toolsUsed: _list(j['tools_used']),
      refused: _list(j['refused']),
    );
  }

  static String? _str(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  static List<String> _list(dynamic v) => v is List
      ? v
          .map((e) => e is Map
              ? (e['reason'] ?? e['tool'] ?? e.toString()).toString()
              : e.toString())
          .where((s) => s.isNotEmpty)
          .toList()
      : const [];
}

class AgentUtteranceResult {
  final AgentReply? reply;
  final String? error;

  /// Relay has no voice-agent route yet (404).
  final bool unsupported;
  const AgentUtteranceResult({this.reply, this.error, this.unsupported = false});
}

/// Voice agent from the phone: one WAV utterance (≤ 30 s / 5 MB) in, text +
/// a short-lived mp3 out. The relay never stores the uploaded audio.
class AgentApi {
  final Dio _dio;
  AgentApi(this._dio);

  Future<AgentUtteranceResult> utterance({
    required String token,
    required String dogId,
    required String filePath,
    String filename = 'utterance.wav',
    void Function(int sent, int total)? onProgress,
  }) async {
    final started = DateTime.now();
    try {
      final form = FormData.fromMap({
        'dog_id': dogId,
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final r = await _dio.post(
        ApiEndpoints.agentUtterance,
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 60),
          // STT + agent + TTS can take a while; the relay itself waits up to
          // 60 s on robot tools (run_trick).
          receiveTimeout: const Duration(seconds: 120),
        ),
        onSendProgress: onProgress,
      );
      final data = r.data;
      if (r.statusCode == 200 && data is Map) {
        final reply = AgentReply.fromJson(data.cast<String, dynamic>());
        connTrace('agent-utterance',
            'ok in ${DateTime.now().difference(started).inMilliseconds}ms tools=${reply.toolsUsed} refused=${reply.refused.length} timing=${r.headers.value('x-agent-timing')}');
        return AgentUtteranceResult(reply: reply);
      }
      return AgentUtteranceResult(error: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        connTrace('agent-utterance', '404 (voice agent not deployed)');
        return const AgentUtteranceResult(unsupported: true);
      }
      final msg = relayErrorMessage(e);
      connTrace('agent-utterance-error', 'status=$status $msg');
      return AgentUtteranceResult(error: msg);
    } catch (e) {
      connTrace('agent-utterance-error', '$e');
      return AgentUtteranceResult(error: '$e');
    }
  }
}
