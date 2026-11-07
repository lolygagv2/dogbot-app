import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../../core/utils/time_utils.dart';

final dogSettingsApiProvider = Provider<DogSettingsApi>((ref) {
  return DogSettingsApi(ref.watch(dioClientProvider));
});

/// One shared per-dog setting row (relay brief 2026-11-06 §2):
/// {key?, value, version, updated_at, updated_by}
class DogSettingRow {
  final String key;
  final Map<String, dynamic> value;
  final int version;
  final DateTime? updatedAt;
  final String? updatedBy;

  const DogSettingRow({
    required this.key,
    required this.value,
    this.version = 0,
    this.updatedAt,
    this.updatedBy,
  });

  static DogSettingRow fromJson(Map<String, dynamic> j, {required String key}) {
    final raw = j['value'];
    return DogSettingRow(
      key: j['key']?.toString() ?? key,
      value: raw is Map ? raw.cast<String, dynamic>() : const {},
      version: (j['version'] as num?)?.toInt() ?? 0,
      updatedAt: tryParseServerTimestamp(j['updated_at']?.toString()),
      updatedBy: j['updated_by']?.toString(),
    );
  }
}

class DogSettingResult {
  final DogSettingRow? row;
  final String? error;

  /// 404: relay has no settings slice (or unknown key).
  final bool unsupported;

  /// 409 version_mismatch — reload and retry.
  final int? currentVersion;
  const DogSettingResult(
      {this.row, this.error, this.unsupported = false, this.currentVersion});
  bool get conflict => currentVersion != null;
}

/// GET / PUT `/api/dogs/{dog}/settings/{key}` (JWT). The app actor is
/// unrestricted; assistants may only widen quiet hours / lower caps.
class DogSettingsApi {
  final Dio _dio;
  DogSettingsApi(this._dio);

  Options _auth(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 10),
      );

  Future<DogSettingResult> get(String token, String dogId, String key) async {
    try {
      final r = await _dio.get(ApiEndpoints.dogSetting(dogId, key),
          options: _auth(token));
      if (r.statusCode == 200 && r.data is Map) {
        return DogSettingResult(
            row: DogSettingRow.fromJson(
                (r.data as Map).cast<String, dynamic>(),
                key: key));
      }
      return DogSettingResult(error: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const DogSettingResult(unsupported: true);
      }
      final msg = relayErrorMessage(e);
      connTrace('dog-setting-get-error', 'key=$key status=${e.response?.statusCode} $msg');
      return DogSettingResult(error: msg);
    }
  }

  Future<DogSettingResult> put(
    String token,
    String dogId,
    String key,
    Map<String, dynamic> value, {
    int? expectedVersion,
  }) async {
    try {
      final r = await _dio.put(
        ApiEndpoints.dogSetting(dogId, key),
        data: {
          'value': value,
          if (expectedVersion != null) 'expected_version': expectedVersion,
        },
        options: _auth(token),
      );
      if (r.statusCode == 200 && r.data is Map) {
        final row = DogSettingRow.fromJson(
            (r.data as Map).cast<String, dynamic>(),
            key: key);
        connTrace('dog-setting-put', 'key=$key v${row.version}');
        return DogSettingResult(row: row);
      }
      return DogSettingResult(error: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return const DogSettingResult(unsupported: true);
      if (relayErrorCode(e) == 'version_mismatch') {
        final detail = (e.response?.data as Map?)?['detail'];
        final cur = detail is Map ? (detail['current_version'] as num?)?.toInt() : null;
        connTrace('dog-setting-put', 'key=$key version_mismatch current=$cur');
        return DogSettingResult(currentVersion: cur ?? -1);
      }
      final msg = relayErrorMessage(e);
      connTrace('dog-setting-put-error', 'key=$key status=$status $msg');
      return DogSettingResult(error: msg);
    }
  }
}
