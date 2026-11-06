import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../models/daily_summary.dart';

final summaryApiProvider = Provider<SummaryApi>((ref) {
  return SummaryApi(ref.watch(dioClientProvider));
});

/// Result of a daily-summary fetch. `summary == null && !notFound` = error.
class DailySummaryResult {
  final DailySummary? summary;
  final bool notFound; // 404: path not served (robot local) — not an error
  final String? error;
  const DailySummaryResult({this.summary, this.notFound = false, this.error});
}

/// GET /summary/{dog}/{date} — relay roll-up (brief 2026-11-06 §1). The
/// relay resolves `today` / `yesterday` in the dog's timezone, so cloud
/// callers pass the token rather than a device-local date; a robot serving
/// the path locally gets YYYY-MM-DD.
class SummaryApi {
  final Dio _dio;
  SummaryApi(this._dio);

  Future<DailySummaryResult> getDaily({
    required String dogId,
    required String date,
    String? token,
    bool refresh = false,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dailySummary(dogId, date),
        queryParameters: refresh ? {'refresh': 1} : null,
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        final map = data.cast<String, dynamic>();
        // Tolerate an envelope ({summary: {...}}).
        final body = map['summary'] is Map
            ? (map['summary'] as Map).cast<String, dynamic>()
            : map;
        final summary = DailySummary.fromJson(body, date: date);
        connTrace('summary-get',
            'dog=$dogId date=${summary.date} events=${summary.eventCount} barks=${summary.stats.barks} treats=${summary.stats.treats}');
        return DailySummaryResult(summary: summary);
      }
      return DailySummaryResult(error: 'HTTP ${response.statusCode}');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        connTrace('summary-get', '404 dog=$dogId date=$date (not served)');
        return const DailySummaryResult(notFound: true);
      }
      final msg = relayErrorMessage(e);
      connTrace('summary-get-error', 'status=$code $msg');
      return DailySummaryResult(error: msg);
    } catch (e) {
      connTrace('summary-get-error', '$e');
      return DailySummaryResult(error: '$e');
    }
  }
}
