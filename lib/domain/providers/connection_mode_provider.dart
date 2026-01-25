import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_connection_service.dart';
import '../../core/utils/remote_logger.dart';
import 'connection_provider.dart';

/// Connection mode - cloud (via relay) or local (direct to robot)
enum ConnectionMode {
  cloud,
  local,
}

/// Provider for current connection mode
final connectionModeProvider =
    StateNotifierProvider<ConnectionModeNotifier, ConnectionMode>((ref) {
  return ConnectionModeNotifier(ref);
});

/// Connection mode notifier
class ConnectionModeNotifier extends StateNotifier<ConnectionMode> {
  final Ref _ref;
  static const String _storageKey = 'connection_mode';

  ConnectionModeNotifier(this._ref) : super(ConnectionMode.cloud) {
    _loadSavedMode();
  }

  Future<void> _loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_storageKey);
      if (savedMode == 'local') {
        state = ConnectionMode.local;
      }
    } catch (e) {
      rprint('ConnectionMode: Failed to load saved mode: $e');
    }
  }

  Future<void> _saveMode(ConnectionMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode == ConnectionMode.local ? 'local' : 'cloud');
    } catch (e) {
      rprint('ConnectionMode: Failed to save mode: $e');
    }
  }

  /// Switch to local mode
  Future<void> setLocalMode() async {
    rprint('ConnectionMode: Switching to LOCAL mode');

    // Disconnect from cloud relay
    await _ref.read(connectionProvider.notifier).disconnect();

    state = ConnectionMode.local;
    await _saveMode(ConnectionMode.local);
  }

  /// Switch to cloud mode
  Future<void> setCloudMode() async {
    rprint('ConnectionMode: Switching to CLOUD mode');

    // Disconnect from local robot
    await _ref.read(localConnectionProvider.notifier).disconnect();

    state = ConnectionMode.cloud;
    await _saveMode(ConnectionMode.cloud);
  }

  /// Toggle between modes
  Future<void> toggleMode() async {
    if (state == ConnectionMode.cloud) {
      await setLocalMode();
    } else {
      await setCloudMode();
    }
  }
}

/// Provider to check if in local mode
final isLocalModeProvider = Provider<bool>((ref) {
  return ref.watch(connectionModeProvider) == ConnectionMode.local;
});

/// Provider to check if in cloud mode
final isCloudModeProvider = Provider<bool>((ref) {
  return ref.watch(connectionModeProvider) == ConnectionMode.cloud;
});

/// Combined connection state - works regardless of mode
final isConnectedAnyModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(connectionModeProvider);

  if (mode == ConnectionMode.local) {
    return ref.watch(localConnectionProvider).isConnected;
  } else {
    return ref.watch(connectionProvider).isConnected;
  }
});

/// Feature gate - returns true if feature is available in current mode
/// Cloud-only features return false in local mode
final cloudOnlyFeatureProvider = Provider.family<bool, String>((ref, feature) {
  final isLocal = ref.watch(isLocalModeProvider);

  // These features require cloud/relay connection
  const cloudOnlyFeatures = {
    'remote_access',      // Access robot when away from home
    'push_notifications', // Alerts via cloud
    'video_recording',    // Cloud-stored recordings
    'event_history',      // Cloud-stored event history
    'multi_device',       // Multiple devices controlling robot
  };

  if (cloudOnlyFeatures.contains(feature)) {
    return !isLocal; // Only available in cloud mode
  }

  return true; // Feature available in both modes
});
