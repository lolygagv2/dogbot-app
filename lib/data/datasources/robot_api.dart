import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/telemetry.dart';
import '../models/mission.dart';

/// Provider for RobotApi
final robotApiProvider = Provider<RobotApi>((ref) {
  return RobotApi(ref.watch(dioClientProvider));
});

/// REST API client for WIM-Z robot
class RobotApi {
  final Dio _dio;

  RobotApi(this._dio);

  // ============ Connection & Status ============

  /// Check if server is reachable
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(ApiEndpoints.health);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get full telemetry data
  Future<Telemetry> getTelemetry() async {
    final response = await _dio.get(ApiEndpoints.telemetry);
    return Telemetry.fromApiResponse(response.data as Map<String, dynamic>);
  }

  // ============ Motor Control ============

  /// Set motor speeds (-1.0 to 1.0)
  Future<void> setMotorSpeed(double left, double right) async {
    await _dio.post(ApiEndpoints.motorSpeed, data: {
      'left': left.clamp(-1.0, 1.0),
      'right': right.clamp(-1.0, 1.0),
    });
  }

  /// Stop all motors
  Future<void> stopMotors() async {
    await _dio.post(ApiEndpoints.motorStop);
  }

  /// Emergency stop
  Future<void> emergencyStop() async {
    await _dio.post(ApiEndpoints.motorEmergency);
  }

  // ============ Camera & Servos ============

  /// Get camera snapshot URL
  String getSnapshotUrl() => '${_dio.options.baseUrl}${ApiEndpoints.cameraSnapshot}';

  /// Get camera stream URL
  String getStreamUrl() => '${_dio.options.baseUrl}${ApiEndpoints.cameraStream}';

  /// Set pan angle
  Future<void> setPan(double angle) async {
    await _dio.post(ApiEndpoints.servoPan, data: {'angle': angle});
  }

  /// Set tilt angle
  Future<void> setTilt(double angle) async {
    await _dio.post(ApiEndpoints.servoTilt, data: {'angle': angle});
  }

  /// Center camera servos
  Future<void> centerCamera() async {
    await _dio.post(ApiEndpoints.servoCenter);
  }

  // ============ Treat Dispenser ============

  /// Dispense one treat
  Future<void> dispenseTreat() async {
    await _dio.post(ApiEndpoints.treatDispense);
  }

  /// Rotate carousel
  Future<void> rotateCarousel() async {
    await _dio.post(ApiEndpoints.treatCarouselRotate);
  }

  // ============ LED Control ============

  /// Set LED pattern
  Future<void> setLedPattern(String pattern) async {
    await _dio.post(ApiEndpoints.ledPattern, data: {'pattern': pattern});
  }

  /// Set LED color
  Future<void> setLedColor(int r, int g, int b) async {
    await _dio.post(ApiEndpoints.ledColor, data: {'r': r, 'g': g, 'b': b});
  }

  /// Turn off LEDs
  Future<void> turnOffLeds() async {
    await _dio.post(ApiEndpoints.ledOff);
  }

  // ============ Audio ============

  /// Play audio file
  Future<void> playAudio(String filename) async {
    await _dio.post(ApiEndpoints.audioPlay, data: {'file': filename});
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    await _dio.post(ApiEndpoints.audioStop);
  }

  /// Set volume level (0-100)
  Future<void> setVolume(int level) async {
    await _dio.post(ApiEndpoints.audioVolume, data: {'level': level.clamp(0, 100)});
  }

  /// Get list of audio files
  Future<List<String>> getAudioFiles() async {
    final response = await _dio.get(ApiEndpoints.audioFiles);
    final data = response.data;
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    if (data is Map && data['files'] is List) {
      return (data['files'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  // ============ Mode Control ============

  /// Get current mode
  Future<String> getMode() async {
    final response = await _dio.get(ApiEndpoints.modeGet);
    final data = response.data;
    if (data is String) return data;
    if (data is Map) return data['mode'] as String? ?? 'idle';
    return 'idle';
  }

  /// Set mode
  Future<void> setMode(String mode) async {
    await _dio.post(ApiEndpoints.modeSet, data: {'mode': mode});
  }

  // ============ Missions ============

  /// Get all missions
  Future<List<Mission>> getMissions() async {
    final response = await _dio.get(ApiEndpoints.missions);
    final data = response.data;
    if (data is List) {
      return data
          .map((e) => Mission.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get mission by ID
  Future<Mission> getMission(String id) async {
    final response = await _dio.get(ApiEndpoints.missionById(id));
    return Mission.fromJson(response.data as Map<String, dynamic>);
  }

  /// Start a mission
  Future<void> startMission(String id) async {
    await _dio.post(ApiEndpoints.missionStart(id));
  }

  /// Stop a mission
  Future<void> stopMission(String id) async {
    await _dio.post(ApiEndpoints.missionStop(id));
  }

  /// Get active mission
  Future<Mission?> getActiveMission() async {
    try {
      final response = await _dio.get(ApiEndpoints.missionActive);
      if (response.data == null) return null;
      return Mission.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}
