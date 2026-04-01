import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';

/// Keys for persisted settings
class SettingsKeys {
  static const motorTrimRight = 'motor_trim_right';
  static const cameraTrackingEnabled = 'camera_tracking_enabled';
  static const backgroundAudioEnabled = 'background_audio_enabled';
  static const dailyLimitEnabled = 'daily_limit_enabled';
  static const dailyLimitCount = 'daily_limit_count';
  static const localModeEnabled = 'local_mode_enabled';
  static const localModeIp = 'local_mode_ip';
  static const localModePort = 'local_mode_port';
}

/// App settings state
class AppSettings {
  /// Motor trim for right motor (-0.5 to 0.5)
  /// Positive values slow down right motor (robot drifts left naturally)
  /// Negative values speed up right motor (robot drifts right naturally)
  final double motorTrimRight;

  /// Camera tracking enabled (Build 38)
  /// When true, camera follows detected dog in coach/mission mode
  final bool cameraTrackingEnabled;

  /// Background audio enabled
  /// When true, WebRTC audio continues when app is backgrounded
  final bool backgroundAudioEnabled;

  /// Daily treat/reward limit — optional cap on auto-dispensed treats per day
  final bool dailyLimitEnabled;
  final int dailyLimitCount;

  /// Local mode — connect directly to Pi on LAN (skip relay + auth)
  final bool localModeEnabled;
  final String localModeIp;
  final int localModePort;

  const AppSettings({
    this.motorTrimRight = 0.0,
    this.cameraTrackingEnabled = false,
    this.backgroundAudioEnabled = true,
    this.dailyLimitEnabled = false,
    this.dailyLimitCount = 30,
    this.localModeEnabled = false,
    this.localModeIp = '',
    this.localModePort = 8000,
  });

  AppSettings copyWith({
    double? motorTrimRight,
    bool? cameraTrackingEnabled,
    bool? backgroundAudioEnabled,
    bool? dailyLimitEnabled,
    int? dailyLimitCount,
    bool? localModeEnabled,
    String? localModeIp,
    int? localModePort,
  }) {
    return AppSettings(
      motorTrimRight: motorTrimRight ?? this.motorTrimRight,
      cameraTrackingEnabled: cameraTrackingEnabled ?? this.cameraTrackingEnabled,
      backgroundAudioEnabled: backgroundAudioEnabled ?? this.backgroundAudioEnabled,
      dailyLimitEnabled: dailyLimitEnabled ?? this.dailyLimitEnabled,
      dailyLimitCount: dailyLimitCount ?? this.dailyLimitCount,
      localModeEnabled: localModeEnabled ?? this.localModeEnabled,
      localModeIp: localModeIp ?? this.localModeIp,
      localModePort: localModePort ?? this.localModePort,
    );
  }
}

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

/// Settings notifier - manages app settings with persistence
class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;
  SharedPreferences? _prefs;

  SettingsNotifier(this._ref) : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    final motorTrim = _prefs?.getDouble(SettingsKeys.motorTrimRight) ?? 0.0;
    final cameraTracking = _prefs?.getBool(SettingsKeys.cameraTrackingEnabled) ?? false;
    final backgroundAudio = _prefs?.getBool(SettingsKeys.backgroundAudioEnabled) ?? true;
    final dailyLimitEnabled = _prefs?.getBool(SettingsKeys.dailyLimitEnabled) ?? false;
    final dailyLimitCount = _prefs?.getInt(SettingsKeys.dailyLimitCount) ?? 30;
    final localModeEnabled = _prefs?.getBool(SettingsKeys.localModeEnabled) ?? false;
    final localModeIp = _prefs?.getString(SettingsKeys.localModeIp) ?? '';
    final localModePort = _prefs?.getInt(SettingsKeys.localModePort) ?? 8000;

    state = AppSettings(
      motorTrimRight: motorTrim.clamp(-0.5, 0.5),
      cameraTrackingEnabled: cameraTracking,
      backgroundAudioEnabled: backgroundAudio,
      dailyLimitEnabled: dailyLimitEnabled,
      dailyLimitCount: dailyLimitCount.clamp(1, 200),
      localModeEnabled: localModeEnabled,
      localModeIp: localModeIp,
      localModePort: localModePort,
    );
  }

  /// Set motor trim for right motor
  /// Range: -0.5 to 0.5 (or -50% to +50%)
  Future<void> setMotorTrimRight(double trim) async {
    final clampedTrim = trim.clamp(-0.5, 0.5);
    state = state.copyWith(motorTrimRight: clampedTrim);
    await _prefs?.setDouble(SettingsKeys.motorTrimRight, clampedTrim);
  }

  /// Reset motor trim to zero
  Future<void> resetMotorTrim() async {
    await setMotorTrimRight(0.0);
  }

  /// Toggle camera tracking (Build 38)
  /// Sends command to robot to enable/disable dog tracking with camera
  Future<void> setCameraTrackingEnabled(bool enabled) async {
    state = state.copyWith(cameraTrackingEnabled: enabled);
    await _prefs?.setBool(SettingsKeys.cameraTrackingEnabled, enabled);

    // Send to robot
    final ws = _ref.read(websocketClientProvider);
    ws.sendSetTrackingEnabled(enabled);
    print('Settings: Camera tracking set to $enabled');
  }

  /// Toggle camera tracking
  Future<void> toggleCameraTracking() async {
    await setCameraTrackingEnabled(!state.cameraTrackingEnabled);
  }

  /// Set background audio enabled
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    state = state.copyWith(backgroundAudioEnabled: enabled);
    await _prefs?.setBool(SettingsKeys.backgroundAudioEnabled, enabled);
    print('Settings: Background audio set to $enabled');
  }

  /// Toggle daily treat limit on/off
  Future<void> setDailyLimitEnabled(bool enabled) async {
    state = state.copyWith(dailyLimitEnabled: enabled);
    await _prefs?.setBool(SettingsKeys.dailyLimitEnabled, enabled);
    _sendDailyLimitToRobot();
  }

  /// Set daily treat limit count
  Future<void> setDailyLimitCount(int count) async {
    final clamped = count.clamp(1, 200);
    state = state.copyWith(dailyLimitCount: clamped);
    await _prefs?.setInt(SettingsKeys.dailyLimitCount, clamped);
    _sendDailyLimitToRobot();
  }

  /// Send daily limit config to robot via mission_config command
  void _sendDailyLimitToRobot() {
    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('mission_config', {
      'daily_limit_enabled': state.dailyLimitEnabled,
      'daily_limit': state.dailyLimitCount,
    });
    print('Settings: Daily limit ${state.dailyLimitEnabled ? "ON (${state.dailyLimitCount})" : "OFF"}');
  }

  /// Toggle local mode on/off
  Future<void> setLocalModeEnabled(bool enabled) async {
    state = state.copyWith(localModeEnabled: enabled);
    await _prefs?.setBool(SettingsKeys.localModeEnabled, enabled);
    print('Settings: Local mode ${enabled ? "ON" : "OFF"}');
  }

  /// Set local mode IP address
  Future<void> setLocalModeIp(String ip) async {
    state = state.copyWith(localModeIp: ip);
    await _prefs?.setString(SettingsKeys.localModeIp, ip);
  }

  /// Set local mode port
  Future<void> setLocalModePort(int port) async {
    state = state.copyWith(localModePort: port);
    await _prefs?.setInt(SettingsKeys.localModePort, port);
  }
}

/// Provider for just the motor trim value
final motorTrimProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).motorTrimRight;
});

/// Provider for background audio setting
final backgroundAudioProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).backgroundAudioEnabled;
});
