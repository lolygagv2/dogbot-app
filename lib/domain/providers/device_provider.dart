import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/websocket_client.dart';
import 'connection_provider.dart';

/// Provider for paired device ID
final deviceIdProvider =
    StateNotifierProvider<DeviceIdNotifier, String>((ref) {
  return DeviceIdNotifier(ref);
});

/// Device ID state notifier - manages paired robot ID
class DeviceIdNotifier extends StateNotifier<String> {
  final Ref _ref;

  DeviceIdNotifier(this._ref) : super(AppConstants.defaultDeviceId) {
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(AppConstants.keyDeviceId);
    print('DeviceId: Loading saved device_id: ${savedId ?? 'null (using default: ${AppConstants.defaultDeviceId})'}');
    if (savedId != null && savedId.isNotEmpty) {
      state = savedId;
      // Update WebSocket client with loaded device ID
      _ref.read(websocketClientProvider).setTargetDevice(savedId);
      print('DeviceId: Set WebSocket target to $savedId');
    }
  }

  Future<void> setDeviceId(String deviceId) async {
    if (deviceId.isEmpty) return;

    print('DeviceId: Changing device from $state to $deviceId');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDeviceId, deviceId);
    state = deviceId;

    // Update WebSocket client immediately
    _ref.read(websocketClientProvider).setTargetDevice(deviceId);
    print('DeviceId: Updated WebSocket target to $deviceId');

    // Notify connection provider to re-check robot status
    _ref.read(connectionProvider.notifier).onDeviceIdChanged(deviceId);
    print('DeviceId: Notified connection provider of change');
  }

  Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyDeviceId);
    state = AppConstants.defaultDeviceId;
    // Reset WebSocket client to default
    _ref.read(websocketClientProvider).setTargetDevice(AppConstants.defaultDeviceId);
  }
}
