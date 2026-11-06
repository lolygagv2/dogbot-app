import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../models/sound_catalog.dart';

final soundsApiProvider = Provider<SoundsApi>((ref) {
  return SoundsApi(ref.watch(dioClientProvider));
});

/// Sound library endpoints.
///
/// Cloud (token != null) — relay `dog_settings.py`, dog-scoped:
///   GET  /api/dogs/{dog}/sounds                      → {sounds:[…]}
///   POST /api/dogs/{dog}/sounds/{id}?label=&kind=     multipart `file` (wav/mp3 ≤ 5 MB)
///   POST /api/dogs/{dog}/sounds/reset                 ALL back to builtins (no per-id reset)
/// Local-AP (token == null) — robot REST (robot brief 2026-11-06):
///   GET  /sounds · POST /sounds/{group}/{stem}/replace | reset · POST /sounds/reset_all
class SoundsApi {
  final Dio _dio;
  SoundsApi(this._dio);

  static const int maxBytes = 5 * 1024 * 1024;
  static const List<String> allowedExtensions = ['mp3', 'wav'];

  Map<String, String> _auth(String? token) =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  /// Server catalog, or null when the endpoint doesn't exist / fails
  /// (callers fall back to [kDefaultSoundCatalog]).
  Future<List<SoundSlot>?> getCatalog({
    String? token,
    required String dogId,
  }) async {
    final isLocal = token == null;
    try {
      final r = await _dio.get(
        isLocal ? '/sounds' : ApiEndpoints.dogSounds(dogId),
        options: Options(
          headers: _auth(token),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return isLocal ? _parseRobot(r.data) : _parseRelay(r.data);
    } on DioException catch (e) {
      connTrace('sounds-catalog',
          'status=${e.response?.statusCode} local=$isLocal (using default)');
      return null;
    }
  }

  static List<SoundSlot>? _parseRelay(dynamic data) {
    final list = data is Map ? data['sounds'] : data;
    if (list is! List) return null;
    return [
      for (final s in list)
        if (s is Map)
          if (SoundSlot.fromRelay(s.cast<String, dynamic>()) case final slot?)
            slot,
    ];
  }

  /// Lenient: `{sounds:[…]}`, `[…]`, or `{groups:{g:[…]}}` / `{g:[…]}`.
  static List<SoundSlot>? _parseRobot(dynamic data) {
    dynamic list = data is Map ? (data['sounds'] ?? data['items']) : data;
    if (list is List) {
      return [
        for (final s in list)
          if (s is Map)
            if (SoundSlot.fromRobot(s.cast<String, dynamic>()) case final slot?)
              slot,
      ];
    }
    final groups = data is Map ? (data['groups'] ?? data) : null;
    if (groups is Map) {
      final out = <SoundSlot>[];
      groups.forEach((g, rows) {
        if (rows is List) {
          for (final s in rows) {
            final slot = s is Map
                ? SoundSlot.fromRobot(s.cast<String, dynamic>(),
                    groupKey: g.toString())
                : SoundSlot.fromRobot({'stem': s.toString()},
                    groupKey: g.toString());
            if (slot != null) out.add(slot);
          }
        }
      });
      return out.isEmpty ? null : out;
    }
    return null;
  }

  /// Returns null on success, else a short error string.
  Future<String?> replace({
    String? token,
    required String dogId,
    required SoundSlot slot,
    required String filePath,
    required String filename,
    String? label,
    void Function(int sent, int total)? onProgress,
  }) async {
    final isLocal = token == null;
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final r = await _dio.post(
        isLocal
            ? '/sounds/${_group(slot)}/${_stem(slot)}/replace'
            : ApiEndpoints.dogSoundReplace(dogId, slot.id),
        queryParameters: isLocal
            ? null
            : {
                if (label != null && label.isNotEmpty) 'label': label,
                'kind': slot.kind == SoundKind.song ? 'song' : 'sound',
              },
        data: form,
        options: Options(
          headers: _auth(token),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress,
      );
      if (r.statusCode == 200 || r.statusCode == 201) return null;
      return 'HTTP ${r.statusCode}';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = relayErrorMessage(e);
      connTrace('sound-replace-error', 'id=${slot.id} status=$status $msg');
      // Stable sentinel so callers can fall back when the route is absent.
      return status == 404 ? 'HTTP 404' : msg;
    } catch (e) {
      return '$e';
    }
  }

  /// Per-sound factory restore — robot-local only (the relay has no
  /// per-id reset). Returns null on success.
  Future<String?> resetOne({
    String? token,
    required String dogId,
    required SoundSlot slot,
  }) async {
    if (token != null) return 'unsupported';
    return _post('/sounds/${_group(slot)}/${_stem(slot)}/reset', token);
  }

  /// Factory reset every sound (relay: back to builtins + custom files removed).
  Future<String?> resetAll({String? token, required String dogId}) =>
      _post(token == null ? '/sounds/reset_all' : ApiEndpoints.dogSoundsReset(dogId),
          token);

  Future<String?> _post(String path, String? token) async {
    try {
      final r = await _dio.post(
        path,
        options: Options(
          headers: _auth(token),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      if (r.statusCode == 200 || r.statusCode == 204) return null;
      return 'HTTP ${r.statusCode}';
    } on DioException catch (e) {
      final msg = relayErrorMessage(e);
      connTrace('sounds-reset-error', 'path=$path status=${e.response?.statusCode} $msg');
      return msg;
    }
  }

  static String _group(SoundSlot s) =>
      s.robotGroup ?? (s.id.contains('/') ? s.id.split('/').first : 'custom');
  static String _stem(SoundSlot s) =>
      s.stem ?? (s.id.contains('/') ? s.id.split('/').last : s.id);
}
