import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../domain/providers/auth_provider.dart';

/// Paired device model
class PairedDevice {
  final String deviceId;
  final String? name;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime pairedAt;

  PairedDevice({
    required this.deviceId,
    this.name,
    required this.isOnline,
    this.lastSeen,
    required this.pairedAt,
  });

  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      deviceId: json['device_id'] as String,
      name: json['name'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      pairedAt: json['paired_at'] != null
          ? DateTime.parse(json['paired_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Provider for DeviceApi
final deviceApiProvider = Provider<DeviceApi>((ref) {
  final dio = ref.watch(dioClientProvider);
  final token = ref.watch(authTokenProvider);
  return DeviceApi(dio, token);
});

/// REST API client for device pairing operations
class DeviceApi {
  final Dio _dio;
  final String? _token;

  DeviceApi(this._dio, this._token);

  /// Get auth headers
  Map<String, String> get _authHeaders {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }

  /// Get list of user's paired devices
  Future<List<PairedDevice>> getDevices() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.userDevices,
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> devices = data['devices'] ?? data ?? [];
        return devices
            .map((d) => PairedDevice.fromJson(d as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('DeviceApi: Failed to get devices: $e');
      rethrow;
    }
  }

  /// Pair a new device
  Future<bool> pairDevice(String deviceId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.pairDevice,
        data: {'device_id': deviceId},
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('DeviceApi: Failed to pair device: $e');
      rethrow;
    }
  }

  /// Unpair a device
  Future<bool> unpairDevice(String deviceId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.unpairDevice,
        data: {'device_id': deviceId},
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('DeviceApi: Failed to unpair device: $e');
      rethrow;
    }
  }
}
