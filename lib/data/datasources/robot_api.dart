import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/mission.dart';
import '../models/schedule.dart';

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

  /// Fetch available missions from server
  Future<List<Mission>> getMissions(String token) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.missions,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((m) => Mission.fromJson(m as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('RobotApi: Failed to fetch missions: $e');
      return [];
    }
  }

  /// Fetch mission history for a dog
  Future<List<MissionHistoryEntry>> getMissionHistory({
    required String token,
    String? dogId,
    int days = 7,
  }) async {
    try {
      final queryParams = <String, dynamic>{'days': days};
      if (dogId != null) queryParams['dog_id'] = dogId;

      final response = await _dio.get(
        ApiEndpoints.missionHistory,
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((h) => MissionHistoryEntry.fromJson(h as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('RobotApi: Failed to fetch mission history: $e');
      return [];
    }
  }

  /// Fetch mission stats for a dog
  Future<MissionStats?> getMissionStats({
    required String token,
    required String dogId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.missionStats,
        queryParameters: {'dog_id': dogId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        return MissionStats.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('RobotApi: Failed to fetch mission stats: $e');
      return null;
    }
  }

  // ============ Scheduling API ============

  /// Fetch all schedules
  Future<List<MissionSchedule>> getSchedules(String token) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.schedules,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((s) => MissionSchedule.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('RobotApi: Failed to fetch schedules: $e');
      return [];
    }
  }

  /// Create a new schedule
  /// Returns the created schedule, or throws with specific error message
  Future<MissionSchedule?> createSchedule(String token, MissionSchedule schedule) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.schedules,
        data: schedule.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          return MissionSchedule.fromJson(response.data as Map<String, dynamic>);
        }
        return schedule;
      }
      return null;
    } on DioException catch (e) {
      // Build 36: More specific error messages
      final statusCode = e.response?.statusCode;
      String errorMsg;
      if (statusCode == 404) {
        errorMsg = 'Scheduling not supported by server';
      } else if (statusCode == 501) {
        errorMsg = 'Scheduling feature not implemented';
      } else if (statusCode == 503) {
        errorMsg = 'Robot offline - cannot create schedule';
      } else if (statusCode == 401 || statusCode == 403) {
        errorMsg = 'Not authorized to create schedules';
      } else {
        errorMsg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? 'Server error ($statusCode)';
      }
      print('RobotApi: Failed to create schedule: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      print('RobotApi: Failed to create schedule: $e');
      throw Exception('Connection error');
    }
  }

  /// Update an existing schedule
  Future<MissionSchedule?> updateSchedule(String token, MissionSchedule schedule) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.scheduleById(schedule.id),
        data: schedule.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        if (response.data != null) {
          return MissionSchedule.fromJson(response.data as Map<String, dynamic>);
        }
        return schedule;
      }
      return null;
    } catch (e) {
      print('RobotApi: Failed to update schedule: $e');
      return null;
    }
  }

  /// Delete a schedule
  Future<bool> deleteSchedule(String token, String scheduleId) async {
    try {
      final response = await _dio.delete(
        ApiEndpoints.scheduleById(scheduleId),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('RobotApi: Failed to delete schedule: $e');
      return false;
    }
  }

  /// Enable global scheduling
  Future<bool> enableScheduling(String token) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.scheduleEnable,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('RobotApi: Failed to enable scheduling: $e');
      return false;
    }
  }

  /// Disable global scheduling
  Future<bool> disableScheduling(String token) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.scheduleDisable,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('RobotApi: Failed to disable scheduling: $e');
      return false;
    }
  }
}
