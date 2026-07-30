import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../models/dog_profile.dart';
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

  /// Check if server is reachable (3-second timeout to avoid hanging)
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.health,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Create a dog profile on the relay server
  Future<bool> createDog(Map<String, dynamic> profileJson, String token) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.dogs,
        data: profileJson,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('RobotApi: Failed to create dog: $e');
      return false;
    }
  }

  /// A1: Fetch the authenticated user's dog profiles from the relay.
  /// Used to hydrate the app on a fresh install / new device.
  /// Returns an empty list on any error so callers can fall back to local cache.
  Future<List<DogProfile>> getDogs(String token) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dogs,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((d) => DogProfile.fromApiResponse(d as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('RobotApi: Failed to fetch dogs: $e');
      return [];
    }
  }

  // ============ Voice Commands API (A2) ============

  /// A2: Fetch the voice command manifest for a dog.
  /// Returns list of {command_id, audio_url, updated_at, format, size_bytes}.
  Future<List<Map<String, dynamic>>> getVoiceCommands({
    required String token,
    required String dogId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.voiceCommands,
        queryParameters: {'dog_id': dogId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('RobotApi: Failed to fetch voice commands: $e');
      return [];
    }
  }

  /// A2: Upload a voice command WAV to the relay. Relay stores the file and
  /// pushes `voice_command_updated` to the user's robot via WS.
  /// Returns {audio_url, updated_at} on success, null on error.
  Future<Map<String, dynamic>?> uploadVoiceCommand({
    required String token,
    required String dogId,
    required String commandId,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'dog_id': dogId,
        'command_id': commandId,
        'file': await MultipartFile.fromFile(filePath, filename: '$commandId.wav'),
      });
      final response = await _dio.post(
        ApiEndpoints.voiceCommands,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map) {
        return (response.data as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      print('RobotApi: Failed to upload voice command: $e');
      return null;
    }
  }

  /// Push: upsert this device's FCM token + per-type push preferences at the
  /// relay. Same endpoint for first registration, token rotation, and
  /// preference changes — the relay upserts by device_token.
  Future<bool> registerPushDevice({
    required String token,
    required String deviceToken,
    required String platform,
    required List<String> enabledTypes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.pushRegister,
        data: {
          'device_token': deviceToken,
          'platform': platform,
          'enabled_types': enabledTypes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('RobotApi: push register failed: $e');
      return false;
    }
  }

  /// Push: remove this device's token on logout (best-effort).
  Future<bool> unregisterPushDevice({
    required String token,
    required String deviceToken,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.pushUnregister,
        data: {'device_token': deviceToken},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('RobotApi: push unregister failed: $e');
      return false;
    }
  }

  /// A2: Delete a voice command from the relay. Relay pushes
  /// `voice_command_deleted` to the user's robot via WS.
  Future<bool> deleteVoiceCommand({
    required String token,
    required String dogId,
    required String commandId,
  }) async {
    try {
      final response = await _dio.delete(
        ApiEndpoints.voiceCommandDelete(dogId, commandId),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('RobotApi: Failed to delete voice command: $e');
      return false;
    }
  }

  /// A2: Download a voice command WAV from the relay (no-auth file URL).
  /// Returns the bytes, or null on error. Used by the app to restore audio
  /// files on a fresh install.
  Future<List<int>?> downloadVoiceCommand(String audioUrl) async {
    try {
      final response = await _dio.get<List<int>>(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('RobotApi: Failed to download voice command from $audioUrl: $e');
      return null;
    }
  }

  // ============ Activity API (A3) ============

  /// A3: Fetch activity events. dogId optional (omit for all dogs).
  /// Returns {events: [...], next_cursor: str?} or {} on error.
  Future<Map<String, dynamic>> getActivity({
    required String token,
    String? dogId,
    DateTime? since,
    int limit = 100,
    String? cursor,
  }) async {
    try {
      final qp = <String, dynamic>{'limit': limit};
      if (dogId != null) qp['dog_id'] = dogId;
      if (since != null) qp['since'] = since.toUtc().toIso8601String();
      if (cursor != null) qp['cursor'] = cursor;

      final response = await _dio.get(
        ApiEndpoints.activity,
        queryParameters: qp,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      connTrace('activity-get',
          'status=${response.statusCode} qp=$qp dataIsMap=${response.data is Map}');
      if (response.statusCode == 200 && response.data is Map) {
        return (response.data as Map).cast<String, dynamic>();
      }
      return {};
    } catch (e) {
      connTrace('activity-get-error', '$e');
      print('RobotApi: Failed to fetch activity: $e');
      return {};
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

  // ============ WiFi / Network API (Build 66) ============

  /// Scan for available WiFi networks
  /// Returns list of {ssid, signal, security} maps
  Future<List<Map<String, dynamic>>> wifiScan() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.wifiScan,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('RobotApi: WiFi scan failed: $e');
      rethrow;
    }
  }

  /// Connect robot to a WiFi network
  Future<Map<String, dynamic>> wifiConnect({
    required String ssid,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.wifiConnect,
        data: {'ssid': ssid, 'password': password},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('RobotApi: WiFi connect failed: $e');
      rethrow;
    }
  }

  /// Get current network status (AP mode vs WiFi, SSID, IP)
  Future<Map<String, dynamic>> networkStatus() async {
    try {
      final response = await _dio.get(ApiEndpoints.networkStatus);
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('RobotApi: Network status failed: $e');
      rethrow;
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
