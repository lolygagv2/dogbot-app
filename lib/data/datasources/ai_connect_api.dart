import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../models/ai_connection.dart';

final aiConnectApiProvider = Provider<AiConnectApi>((ref) {
  return AiConnectApi(ref.watch(dioClientProvider));
});

/// Thrown when the relay has no Connected-AI slice yet (404 on the root
/// listing). The screen shows a "not available on this server" state.
class AiConnectUnsupported implements Exception {
  const AiConnectUnsupported();
}

/// Relay Connected-AI endpoints (contract §2). All calls carry the user JWT.
class AiConnectApi {
  final Dio _dio;
  AiConnectApi(this._dio);

  Options _auth(String token, {Duration? timeout}) => Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: timeout ?? const Duration(seconds: 10),
      );

  /// {connector_url, enabled, assistants:[...]}
  Future<Map<String, dynamic>> getConnections(String token) async {
    try {
      final r = await _dio.get(ApiEndpoints.aiConnections, options: _auth(token));
      if (r.data is Map) return (r.data as Map).cast<String, dynamic>();
      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const AiConnectUnsupported();
      rethrow;
    }
  }

  Future<List<AiAuditEntry>> getAudit(String token, {int limit = 30}) async {
    try {
      final r = await _dio.get(
        ApiEndpoints.aiAudit,
        queryParameters: {'limit': limit},
        options: _auth(token),
      );
      final data = r.data;
      final list = data is Map ? data['entries'] ?? data['events'] : data;
      if (list is List) {
        return [
          for (final e in list)
            if (e is Map) AiAuditEntry.fromJson(e.cast<String, dynamic>()),
        ];
      }
      return const [];
    } on DioException catch (e) {
      // Audit is optional — a missing endpoint just means an empty log.
      connTrace('ai-audit-error', 'status=${e.response?.statusCode}');
      return const [];
    }
  }

  Future<bool> revoke(String token, String connectionId) async {
    try {
      final r = await _dio.delete(
        ApiEndpoints.aiConnectionRevoke(connectionId),
        options: _auth(token),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } on DioException catch (e) {
      connTrace('ai-revoke-error', 'status=${e.response?.statusCode}');
      // 404 = already gone; treat as revoked.
      return e.response?.statusCode == 404;
    }
  }

  /// enabled=false engages the kill switch (every assistant refused).
  Future<bool> setEnabled(String token, bool enabled) async {
    try {
      final r = await _dio.post(
        ApiEndpoints.aiKillSwitch,
        data: {'enabled': enabled},
        options: _auth(token),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } on DioException catch (e) {
      connTrace('ai-killswitch-error', 'status=${e.response?.statusCode}');
      return false;
    }
  }

  /// Approve/decline a drafted mission. Returns null on success, else an
  /// error string (callers fall back to the WS command).
  Future<String?> decideDraft(
      String token, String draftId, DraftDecision decision) async {
    try {
      final r = await _dio.post(
        ApiEndpoints.aiDraftDecision(draftId),
        data: {'decision': decision.name},
        options: _auth(token),
      );
      if (r.statusCode == 200 || r.statusCode == 204) return null;
      return 'HTTP ${r.statusCode}';
    } on DioException catch (e) {
      connTrace('ai-draft-decision-error', 'status=${e.response?.statusCode}');
      return e.response?.statusCode?.toString() ?? e.message ?? 'error';
    }
  }
}
