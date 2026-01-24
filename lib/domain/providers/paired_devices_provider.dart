import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/datasources/device_api.dart';
import 'device_provider.dart';

/// State for paired devices
class PairedDevicesState {
  final List<PairedDevice> devices;
  final bool isLoading;
  final String? error;
  final Map<String, bool> deviceOnlineStatus;

  const PairedDevicesState({
    this.devices = const [],
    this.isLoading = false,
    this.error,
    this.deviceOnlineStatus = const {},
  });

  PairedDevicesState copyWith({
    List<PairedDevice>? devices,
    bool? isLoading,
    String? error,
    Map<String, bool>? deviceOnlineStatus,
  }) {
    return PairedDevicesState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      deviceOnlineStatus: deviceOnlineStatus ?? this.deviceOnlineStatus,
    );
  }

  /// Get device with live online status
  bool isDeviceOnline(String deviceId) {
    return deviceOnlineStatus[deviceId] ?? false;
  }
}

/// Provider for paired devices state
final pairedDevicesProvider =
    StateNotifierProvider<PairedDevicesNotifier, PairedDevicesState>((ref) {
  return PairedDevicesNotifier(ref);
});

/// Paired devices state notifier
class PairedDevicesNotifier extends StateNotifier<PairedDevicesState> {
  final Ref _ref;
  StreamSubscription? _deviceStatusSubscription;

  PairedDevicesNotifier(this._ref) : super(const PairedDevicesState()) {
    _listenToDeviceStatus();
  }

  /// Listen to WebSocket device status updates
  void _listenToDeviceStatus() {
    final ws = _ref.read(websocketClientProvider);
    _deviceStatusSubscription = ws.deviceStatusStream.listen((status) {
      final deviceId = status['device_id'] as String?;
      final isOnline = status['online'] as bool? ?? status['is_online'] as bool? ?? false;

      if (deviceId != null) {
        final newStatus = Map<String, bool>.from(state.deviceOnlineStatus);
        newStatus[deviceId] = isOnline;
        state = state.copyWith(deviceOnlineStatus: newStatus);
      }
    });
  }

  /// Load paired devices from API
  Future<void> loadDevices() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = _ref.read(deviceApiProvider);
      final devices = await api.getDevices();

      // Initialize online status from device data
      final onlineStatus = <String, bool>{};
      for (final device in devices) {
        onlineStatus[device.deviceId] = device.isOnline;
      }

      state = state.copyWith(
        devices: devices,
        isLoading: false,
        deviceOnlineStatus: onlineStatus,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
    }
  }

  /// Pair a new device
  Future<bool> pairDevice(String deviceId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = _ref.read(deviceApiProvider);
      final success = await api.pairDevice(deviceId);

      if (success) {
        // Reload device list
        await loadDevices();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to pair device',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  /// Unpair a device
  Future<bool> unpairDevice(String deviceId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = _ref.read(deviceApiProvider);
      final success = await api.unpairDevice(deviceId);

      if (success) {
        // Check if unpaired device was the active one
        final currentDeviceId = _ref.read(deviceIdProvider);
        if (currentDeviceId == deviceId) {
          // Clear active device or set to first remaining device
          final remainingDevices = state.devices
              .where((d) => d.deviceId != deviceId)
              .toList();
          if (remainingDevices.isNotEmpty) {
            _ref
                .read(deviceIdProvider.notifier)
                .setDeviceId(remainingDevices.first.deviceId);
          }
        }

        // Reload device list
        await loadDevices();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to unpair device',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  /// Select a device as the active one
  void selectDevice(String deviceId) {
    print('PairedDevices: selectDevice called with $deviceId');
    print('PairedDevices: Current online status map: ${state.deviceOnlineStatus}');
    print('PairedDevices: Device online? ${state.isDeviceOnline(deviceId)}');

    // Set the device ID - this triggers:
    // 1. deviceIdProvider state update
    // 2. WebSocket target device update
    // 3. Connection provider onDeviceIdChanged (requests new status)
    // 4. WebRTC provider device switch
    _ref.read(deviceIdProvider.notifier).setDeviceId(deviceId);

    print('PairedDevices: selectDevice completed for $deviceId');
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  String _parseError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('401') || errorStr.contains('403')) {
      return 'Not authorized. Please log in again.';
    } else if (errorStr.contains('404')) {
      return 'Device not found';
    } else if (errorStr.contains('409')) {
      return 'Device already paired';
    } else if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection')) {
      return 'Network error. Check your connection.';
    }
    return 'An error occurred. Please try again.';
  }

  @override
  void dispose() {
    _deviceStatusSubscription?.cancel();
    super.dispose();
  }
}
