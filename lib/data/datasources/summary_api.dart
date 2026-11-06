import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../models/daily_summary.dart';

final summaryApiProvider = Provider<SummaryApi>((ref) {
  return SummaryApi(ref.watch(dioClientProvider));
});

/// Result of a daily-summary fetch. `summary == null && !notFound` = error.
class DailySummaryResult {
  final DailySummary? summary;
  final bool notFound; // 404: no rows for that day (not an error)
  final String? error;
  const DailySummaryResult({this.summary, this.notFound = false, this.error});
}

/// GET /summary/{dog}/{date} — served by the relay (cloud) or the robot
/// (local mode) at the same path; the Dio base URL already points at the
/// right host for the current connection.
class SummaryApi {
  final Dio _dio;
  SummaryApi(this._dio);

  Future<DailySummaryResult> getDaily({
    required String dogId,
    required String isoDate,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dailySummary(dogId, isoDate),
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        final map = data.cast<String, dynamic>();
        // Tolerate an envelope ({summary: {...}}).
        final body = map['summary'] is Map
            ? (map['summary'] as Map).cast<String, dynamic>()
            : map;
        connTrace('summary-get', 'dog=$dogId date=$isoDate keys=${body.keys.length}');
        return DailySummaryResult(
            summary: DailySummary.fromJson(body, date: isoDate));
      }
      return DailySummaryResult(error: 'HTTP ${response.statusCode}');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        connTrace('summary-get', '404 dog=$dogId date=$isoDate (no data)');
        return const DailySummaryResult(notFound: true);
      }
      connTrace('summary-get-error', 'status=$code ${e.message}');
      return DailySummaryResult(error: e.message ?? 'HTTP $code');
    } catch (e) {
      connTrace('summary-get-error', '$e');
      return DailySummaryResult(error: '$e');
    }
  }
}
