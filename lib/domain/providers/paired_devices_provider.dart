import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../data/datasources/device_api.dart';
import 'auth_provider.dart';
import 'device_provider.dart';

/// Outcome of [PairedDevicesNotifier.unpairDevice]. [orphaned] means the relay
/// reported 404 — i.e. the pairing row points to a device that doesn't exist
/// server-side and can never be cleanly unpaired. The UI can offer to hide it
/// locally via [PairedDevicesNotifier.dismissLocally].
enum UnpairOutcome { success, orphaned, error }

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

  /// Build 94: device IDs the user has chosen to hide from the list because
  /// the relay refused to unpair them (orphaned pairing rows pointing at
  /// non-existent devices). Loaded from SharedPrefs at startup; user-scoped
  /// by email to match the rest of the app's storage conventions.
  Set<String> _dismissedDeviceIds = {};

  String _dismissedKeyForUser(String? email) =>
      'dismissed_devices_${email ?? 'anonymous'}';

  PairedDevicesNotifier(this._ref) : super(const PairedDevicesState()) {
    _listenToDeviceStatus();
    _loadDismissedDevices();
  }

  Future<void> _loadDismissedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = _ref.read(authProvider).email;
      _dismissedDeviceIds =
          (prefs.getStringList(_dismissedKeyForUser(email)) ?? const [])
              .toSet();
    } catch (e) {
      print('PairedDevices: failed to load dismissed list: $e');
    }
  }

  Future<void> _saveDismissedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = _ref.read(authProvider).email;
      await prefs.setStringList(
        _dismissedKeyForUser(email),
        _dismissedDeviceIds.toList(),
      );
    } catch (e) {
      print('PairedDevices: failed to save dismissed list: $e');
    }
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

  /// Load paired devices from API (skip in local mode — no relay)
  Future<void> loadDevices() async {
    // In local mode, no relay API — treat as single paired device
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    if (isLocal) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = _ref.read(deviceApiProvider);
      final devices = await api.getDevices();

      // Build 94: hide pairings the user dismissed locally because the relay
      // refused to unpair them. The orphaned row stays on the relay, but the
      // UI is no longer stuck.
      final visible = devices
          .where((d) => !_dismissedDeviceIds.contains(d.deviceId))
          .toList();

      // Build 104: merge REST + live WS status. The live deviceStatusStream is
      // the truth — REST `device.isOnline` lags right after pairing and was
      // overwriting the WS-derived "online" with a stale "offline", which
      // caused the settings + pairing screens to disagree with each other and
      // with reality. Keep any existing live entry; use REST only for devices
      // we haven't heard about over WS yet.
      final mergedStatus = Map<String, bool>.from(state.deviceOnlineStatus);
      for (final device in visible) {
        mergedStatus.putIfAbsent(device.deviceId, () => device.isOnline);
      }

      state = state.copyWith(
        devices: visible,
        isLoading: false,
        deviceOnlineStatus: mergedStatus,
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
        // Build 104: optimistic — if the user successfully paired this
        // device, they almost certainly tapped it from the discoverable list
        // where it was showing "online". Seed the live status map before
        // loadDevices() runs so the post-pair UI doesn't briefly flip to
        // "offline" while the relay catches up. The next deviceStatusStream
        // tick will overwrite this with truth.
        final seeded = Map<String, bool>.from(state.deviceOnlineStatus);
        seeded[deviceId] = true;
        state = state.copyWith(deviceOnlineStatus: seeded);

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

  /// Unpair a device. Returns an [UnpairOutcome] so the UI can offer the
  /// local-dismiss path on [UnpairOutcome.orphaned] (relay 404, dead pairing).
  Future<UnpairOutcome> unpairDevice(String deviceId) async {
    state = state.copyWith(isLoading: true, error: null);

    final api = _ref.read(deviceApiProvider);
    final code = await api.unpairDevice(deviceId);

    if (code == 200) {
      _onDeviceRemovedFromList(deviceId);
      await loadDevices();
      return UnpairOutcome.success;
    }

    if (code == 404) {
      // Pairing row exists on the relay but the device record doesn't —
      // server can't (or won't) finish the delete. Let the UI offer to
      // hide it locally.
      state = state.copyWith(isLoading: false);
      return UnpairOutcome.orphaned;
    }

    state = state.copyWith(
      isLoading: false,
      error: code == null
          ? 'Network error. Check your connection.'
          : 'Failed to unpair device (status $code)',
    );
    return UnpairOutcome.error;
  }

  /// Build 94: hide a device locally — used when the relay can't unpair it.
  /// The pairing row stays orphaned server-side, but the user is unblocked.
  Future<void> dismissLocally(String deviceId) async {
    _dismissedDeviceIds.add(deviceId);
    await _saveDismissedDevices();
    _onDeviceRemovedFromList(deviceId);
    await loadDevices();
  }

  /// If the active device just disappeared from the list, fall back to
  /// whichever paired device is still around (or clear it).
  void _onDeviceRemovedFromList(String deviceId) {
    final currentDeviceId = _ref.read(deviceIdProvider);
    if (currentDeviceId != deviceId) return;
    final remaining = state.devices.where((d) => d.deviceId != deviceId);
    if (remaining.isNotEmpty) {
      _ref.read(deviceIdProvider.notifier).setDeviceId(remaining.first.deviceId);
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
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('401') || errorStr.contains('403')) {
      return 'Not authorized. Please log in again.';
    } else if (errorStr.contains('404')) {
      return 'Device not found. Check the device ID.';
    } else if (errorStr.contains('409')) {
      return 'Device already paired to your account.';
    } else if (errorStr.contains('503') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('offline')) {
      // Issue 6b: Show "Robot unavailable" when robot is offline
      return 'Robot unavailable. Make sure it is powered on and connected.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. Robot may be unavailable.';
    } else if (errorStr.contains('socketexception') ||
        errorStr.contains('connection')) {
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
