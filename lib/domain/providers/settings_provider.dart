import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for persisted settings
class SettingsKeys {
  static const motorTrimRight = 'motor_trim_right';
}

/// App settings state
class AppSettings {
  /// Motor trim for right motor (-0.2 to 0.2)
  /// Positive values slow down right motor (robot drifts left naturally)
  /// Negative values speed up right motor (robot drifts right naturally)
  final double motorTrimRight;

  const AppSettings({
    this.motorTrimRight = 0.0,
  });

  AppSettings copyWith({
    double? motorTrimRight,
  }) {
    return AppSettings(
      motorTrimRight: motorTrimRight ?? this.motorTrimRight,
    );
  }
}

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Settings notifier - manages app settings with persistence
class SettingsNotifier extends StateNotifier<AppSettings> {
  SharedPreferences? _prefs;

  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    final motorTrim = _prefs?.getDouble(SettingsKeys.motorTrimRight) ?? 0.0;

    state = AppSettings(
      motorTrimRight: motorTrim.clamp(-0.2, 0.2),
    );
  }

  /// Set motor trim for right motor
  /// Range: -0.2 to 0.2 (or -20% to +20%)
  Future<void> setMotorTrimRight(double trim) async {
    final clampedTrim = trim.clamp(-0.2, 0.2);
    state = state.copyWith(motorTrimRight: clampedTrim);
    await _prefs?.setDouble(SettingsKeys.motorTrimRight, clampedTrim);
  }

  /// Reset motor trim to zero
  Future<void> resetMotorTrim() async {
    await setMotorTrimRight(0.0);
  }
}

/// Provider for just the motor trim value
final motorTrimProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).motorTrimRight;
});
