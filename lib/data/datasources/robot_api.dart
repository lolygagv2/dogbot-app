import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';

/// Provider for RobotApi
final robotApiProvider = Provider<RobotApi>((ref) {
  return RobotApi(ref.watch(dioClientProvider));
});

/// REST API client for relay server
/// Note: All robot commands go through WebSocket.
/// This client is only used for health checks and auth.
class RobotApi {
  final Dio _dio;

  RobotApi(this._dio);

  /// Check if server is reachable
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(ApiEndpoints.health);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete a dog profile from the relay server
  Future<bool> deleteDog(String dogId, String token) async {
    try {
      final response = await _dio.delete(
        ApiEndpoints.dogDelete(dogId),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('RobotApi: Failed to delete dog $dogId: $e');
      return false;
    }
  }
}
