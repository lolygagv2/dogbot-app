import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';

/// Keys for persisted settings
class SettingsKeys {
  static const motorTrimRight = 'motor_trim_right';
  static const cameraTrackingEnabled = 'camera_tracking_enabled';
  static const backgroundAudioEnabled = 'background_audio_enabled';
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

  const AppSettings({
    this.motorTrimRight = 0.0,
    this.cameraTrackingEnabled = false,
    this.backgroundAudioEnabled = true,
  });

  AppSettings copyWith({
    double? motorTrimRight,
    bool? cameraTrackingEnabled,
    bool? backgroundAudioEnabled,
  }) {
    return AppSettings(
      motorTrimRight: motorTrimRight ?? this.motorTrimRight,
      cameraTrackingEnabled: cameraTrackingEnabled ?? this.cameraTrackingEnabled,
      backgroundAudioEnabled: backgroundAudioEnabled ?? this.backgroundAudioEnabled,
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

    state = AppSettings(
      motorTrimRight: motorTrim.clamp(-0.5, 0.5),
      cameraTrackingEnabled: cameraTracking,
      backgroundAudioEnabled: backgroundAudio,
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
}

/// Provider for just the motor trim value
final motorTrimProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).motorTrimRight;
});

/// Provider for background audio setting
final backgroundAudioProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).backgroundAudioEnabled;
});
