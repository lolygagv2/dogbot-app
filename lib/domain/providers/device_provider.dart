import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Provider for paired device ID
final deviceIdProvider =
    StateNotifierProvider<DeviceIdNotifier, String>((ref) {
  return DeviceIdNotifier();
});

/// Device ID state notifier - manages paired robot ID
class DeviceIdNotifier extends StateNotifier<String> {
  DeviceIdNotifier() : super(AppConstants.defaultDeviceId) {
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(AppConstants.keyDeviceId);
    if (savedId != null && savedId.isNotEmpty) {
      state = savedId;
    }
  }

  Future<void> setDeviceId(String deviceId) async {
    if (deviceId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDeviceId, deviceId);
    state = deviceId;
  }

  Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyDeviceId);
    state = AppConstants.defaultDeviceId;
  }
}
