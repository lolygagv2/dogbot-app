import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../models/ai_connection.dart';

final aiConnectApiProvider = Provider<AiConnectApi>((ref) {
  return AiConnectApi(ref.watch(dioClientProvider));
});

/// Thrown when the relay has no Connected-AI slice yet (404 on the root
/// listing). The screen shows a "not available on this server" state.
class AiConnectUnsupported implements Exception {
  const AiConnectUnsupported();
}

/// Outcome of PUT …/missions/drafts/{id}. `error == null` = decided.
class DraftDecisionResult {
  final String? error;
  final String? status; // approved | declined (relay echo)
  final String? missionId; // on approve
  const DraftDecisionResult({this.error, this.status, this.missionId});
}

/// Relay Connected-AI + mission-draft endpoints (brief 2026-11-06 §4/§5,
/// routers `ai.py` / `mission_drafts.py`). Dog-scoped; all calls carry the
/// user JWT (the relay rejects connector/agent/robot actors on these).
class AiConnectApi {
  final Dio _dio;
  AiConnectApi(this._dio);

  Options _auth(String token, {Duration? timeout}) => Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: timeout ?? const Duration(seconds: 10),
      );

  /// {connector_url, assistants:[{client_id, client_name, scopes, …}]}
  Future<Map<String, dynamic>> getConnectors(String token, String dogId) async {
    try {
      final r = await _dio.get(ApiEndpoints.aiConnectors(dogId),
          options: _auth(token));
      if (r.data is Map) return (r.data as Map).cast<String, dynamic>();
      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const AiConnectUnsupported();
      rethrow;
    }
  }

  Future<List<AiAuditEntry>> getAudit(String token, String dogId,
      {int limit = 50}) async {
    try {
      final r = await _dio.get(
        ApiEndpoints.aiAudit(dogId),
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

  /// POST …/ai/connectors/{client_id}/revoke → {client_id, revoked:n}
  Future<bool> revoke(String token, String dogId, String clientId) async {
    try {
      final r = await _dio.post(
        ApiEndpoints.aiConnectorRevoke(dogId, clientId),
        options: _auth(token),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } on DioException catch (e) {
      connTrace('ai-revoke-error',
          'status=${e.response?.statusCode} ${relayErrorMessage(e)}');
      // 404 = already gone; treat as revoked.
      return e.response?.statusCode == 404;
    }
  }

  /// POST …/ai/revoke_all → {revoked:n}. The relay's "kill switch": every
  /// assistant loses its tokens and must re-authorize. Null on failure.
  Future<int?> revokeAll(String token, String dogId) async {
    try {
      final r = await _dio.post(ApiEndpoints.aiRevokeAll(dogId),
          options: _auth(token));
      if (r.statusCode != 200 && r.statusCode != 204) return null;
      final data = r.data;
      return data is Map ? (data['revoked'] as num?)?.toInt() ?? 0 : 0;
    } on DioException catch (e) {
      connTrace('ai-revoke-all-error',
          'status=${e.response?.statusCode} ${relayErrorMessage(e)}');
      return null;
    }
  }

  /// GET …/missions/drafts?status=all → drafts[]; null when the relay
  /// doesn't serve the route (404) or on error.
  Future<List<MissionDraft>?> listDrafts(String token, String dogId,
      {String status = 'all', int limit = 50}) async {
    try {
      final r = await _dio.get(
        ApiEndpoints.missionDrafts(dogId),
        queryParameters: {'status': status, 'limit': limit},
        options: _auth(token),
      );
      final data = r.data;
      final list = data is Map ? data['drafts'] : data;
      if (list is! List) return const [];
      return [
        for (final d in list)
          if (d is Map)
            if (MissionDraft.fromEvent(d.cast<String, dynamic>()) case final m?)
              m,
      ];
    } on DioException catch (e) {
      connTrace('drafts-list-error',
          'status=${e.response?.statusCode} ${relayErrorMessage(e)}');
      return null;
    }
  }

  /// PUT …/missions/drafts/{draft_id} {decision}. A 409
  /// `draft_already_decided` is reported as success with the relay's status.
  Future<DraftDecisionResult> decideDraft(
      String token, String dogId, String draftId, DraftDecision decision) async {
    try {
      final r = await _dio.put(
        ApiEndpoints.missionDraft(dogId, draftId),
        data: {'decision': decision.name},
        options: _auth(token, timeout: const Duration(seconds: 15)),
      );
      final data = r.data;
      if (r.statusCode == 200 && data is Map) {
        return DraftDecisionResult(
          status: data['status']?.toString(),
          missionId: data['mission_id']?.toString(),
        );
      }
      if (r.statusCode == 200 || r.statusCode == 204) {
        return const DraftDecisionResult();
      }
      return DraftDecisionResult(error: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      final code = relayErrorCode(e);
      if (code == 'draft_already_decided') {
        final detail = (e.response?.data as Map?)?['detail'];
        return DraftDecisionResult(
            status: detail is Map ? detail['status']?.toString() : null);
      }
      final msg = relayErrorMessage(e);
      connTrace('ai-draft-decision-error', 'status=${e.response?.statusCode} $msg');
      return DraftDecisionResult(error: msg);
    }
  }
}
