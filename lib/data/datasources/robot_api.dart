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
      print('[SCHEDULE] GET /schedules...');
      final response = await _dio.get(
        ApiEndpoints.schedules,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('[SCHEDULE] GET response: status=${response.statusCode}, data=${response.data}');
      if (response.statusCode == 200 && response.data is List) {
        final schedules = (response.data as List)
            .map((s) {
              print('[SCHEDULE] Parsing: $s');
              return MissionSchedule.fromJson(s as Map<String, dynamic>);
            })
            .toList();
        print('[SCHEDULE] Parsed ${schedules.length} schedules');
        return schedules;
      }
      print('[SCHEDULE] GET returned non-list or error: ${response.data}');
      return [];
    } catch (e) {
      print('[SCHEDULE] Failed to fetch schedules: $e');
      return [];
    }
  }

  /// Create a new schedule
  /// Returns the created schedule, or throws with specific error message
  Future<MissionSchedule?> createSchedule(String token, MissionSchedule schedule) async {
    try {
      final json = schedule.toJson();
      print('[SCHEDULE] POST /schedules with: $json');
      final response = await _dio.post(
        ApiEndpoints.schedules,
        data: json,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('[SCHEDULE] POST response: status=${response.statusCode}, data=${response.data}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          print('[SCHEDULE] Parsing response...');
          return MissionSchedule.fromJson(response.data as Map<String, dynamic>);
        }
        print('[SCHEDULE] No response data, returning original schedule');
        return schedule;
      }
      print('[SCHEDULE] Unexpected status: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      // Build 36: More specific error messages
      final statusCode = e.response?.statusCode;
      print('[SCHEDULE] DioException: status=$statusCode, response=${e.response?.data}');
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
      print('[SCHEDULE] Failed to create: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      print('[SCHEDULE] Failed to create schedule: $e');
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

  // ============ Music Upload API (Build 38) ============

  /// Upload MP3 file via HTTP multipart (instead of WebSocket)
  /// Returns error message on failure, null on success
  /// Build 40: Added device_id field - relay requires all 3 fields (file, dog_id, device_id)
  Future<String?> uploadMusic({
    required String token,
    required String filePath,
    required String filename,
    required String dogId,
    required String deviceId,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      print('[MUSIC-UPLOAD] Starting HTTP multipart upload: $filename');
      print('[MUSIC-UPLOAD] dogId: $dogId, deviceId: $deviceId, path: $filePath');

      // Build 40: Relay requires all 3 form fields - file, dog_id, device_id
      final formData = FormData.fromMap({
        'dog_id': dogId,
        'device_id': deviceId,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filename,
        ),
      });

      final response = await _dio.post(
        ApiEndpoints.musicUpload,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // Longer timeout for large files
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress,
      );

      print('[MUSIC-UPLOAD] Response: status=${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[MUSIC-UPLOAD] Upload successful');
        return null; // Success
      }

      final errorMsg = response.data?['error'] ?? 'Upload failed (${response.statusCode})';
      print('[MUSIC-UPLOAD] Upload failed: $errorMsg');
      return errorMsg;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      print('[MUSIC-UPLOAD] DioException: status=$statusCode, ${e.message}');

      String errorMsg;
      if (statusCode == 413) {
        errorMsg = 'File too large for server';
      } else if (statusCode == 415) {
        errorMsg = 'Invalid file type - MP3 only';
      } else if (statusCode == 401 || statusCode == 403) {
        errorMsg = 'Not authorized to upload';
      } else if (statusCode == 503) {
        errorMsg = 'Robot offline';
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        errorMsg = 'Upload timed out - try a smaller file';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg = 'Connection error - check network';
      } else {
        errorMsg = e.response?.data?['error'] ?? e.message ?? 'Upload failed';
      }
      return errorMsg;
    } catch (e) {
      print('[MUSIC-UPLOAD] Error: $e');
      return 'Upload error: $e';
    }
  }
}
