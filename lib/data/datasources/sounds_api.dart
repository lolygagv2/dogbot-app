import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../models/sound_catalog.dart';

final soundsApiProvider = Provider<SoundsApi>((ref) {
  return SoundsApi(ref.watch(dioClientProvider));
});

/// Robot sound catalog endpoints (contract §3). Replace is a multipart
/// upload keyed by sound id; the relay forwards to the selected robot
/// (device_id), the same way /api/music/upload does.
class SoundsApi {
  final Dio _dio;
  SoundsApi(this._dio);

  Map<String, String> _auth(String? token) =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  /// Robot-reported catalog, or null when the endpoint doesn't exist yet
  /// (callers fall back to [kDefaultSoundCatalog]).
  Future<List<SoundSlot>?> getCatalog({
    String? token,
    required String deviceId,
  }) async {
    try {
      final r = await _dio.get(
        ApiEndpoints.sounds,
        queryParameters: {'device_id': deviceId},
        options: Options(
          headers: _auth(token),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = r.data;
      final list = data is Map ? data['sounds'] : data;
      if (list is! List) return null;
      return [
        for (final s in list)
          if (s is Map && s['id'] != null)
            SoundSlot(
              id: s['id'].toString(),
              group: SoundSlot.groupFromWire(
                  s['group']?.toString(), s['id'].toString()),
              label: s['label']?.toString(),
              custom: s['custom'] == true,
            ),
      ];
    } on DioException catch (e) {
      connTrace('sounds-catalog', 'status=${e.response?.statusCode} (using default)');
      return null;
    }
  }

  /// Returns null on success, else a short error string.
  Future<String?> replace({
    String? token,
    required String deviceId,
    required String soundId,
    required String filePath,
    required String filename,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'device_id': deviceId,
        'sound_id': soundId,
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final r = await _dio.post(
        ApiEndpoints.soundReplace(soundId),
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
      connTrace('sound-replace-error', 'id=$soundId status=${e.response?.statusCode}');
      final body = e.response?.data;
      if (body is Map && body['error'] != null) return body['error'].toString();
      return e.response?.statusCode != null
          ? 'HTTP ${e.response!.statusCode}'
          : (e.message ?? 'error');
    } catch (e) {
      return '$e';
    }
  }

  /// Factory reset every sound (or one id when [soundId] given).
  Future<String?> reset({
    String? token,
    required String deviceId,
    String? soundId,
  }) async {
    try {
      final r = await _dio.post(
        ApiEndpoints.soundsReset,
        data: {'device_id': deviceId, if (soundId != null) 'sound_id': soundId},
        options: Options(
          headers: _auth(token),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      if (r.statusCode == 200 || r.statusCode == 204) return null;
      return 'HTTP ${r.statusCode}';
    } on DioException catch (e) {
      connTrace('sounds-reset-error', 'status=${e.response?.statusCode}');
      return e.response?.statusCode != null
          ? 'HTTP ${e.response!.statusCode}'
          : (e.message ?? 'error');
    }
  }
}
