/// Robot day/night camera mode. The robot decides this from its ambient light
/// sensor (NoIR camera + lux reading) when override is [NightModeOverride.auto];
/// otherwise it follows the user's pinned choice.
enum DayNight {
  day,
  night;

  static DayNight? fromString(String? s) {
    switch (s) {
      case 'day':
        return DayNight.day;
      case 'night':
        return DayNight.night;
      default:
        return null;
    }
  }
}

/// User's pinned preference for the robot's day/night camera mode. The robot
/// persists this server-side; the app just reflects the latest value the robot
/// publishes in [NightModeState].
enum NightModeOverride {
  auto,
  forceDay,
  forceNight;

  /// Parse the robot's wire value ('auto'/'force_day'/'force_night').
  static NightModeOverride? fromString(String? s) {
    switch (s) {
      case 'auto':
        return NightModeOverride.auto;
      case 'force_day':
        return NightModeOverride.forceDay;
      case 'force_night':
        return NightModeOverride.forceNight;
      default:
        return null;
    }
  }

  /// Serialise back to the robot's wire value.
  String get wireValue {
    switch (this) {
      case NightModeOverride.auto:
        return 'auto';
      case NightModeOverride.forceDay:
        return 'force_day';
      case NightModeOverride.forceNight:
        return 'force_night';
    }
  }

  String get label {
    switch (this) {
      case NightModeOverride.auto:
        return 'Auto';
      case NightModeOverride.forceDay:
        return 'Day mode';
      case NightModeOverride.forceNight:
        return 'Night mode';
    }
  }
}

/// Snapshot of the robot's day/night camera state. Pushed by the robot on
/// transition and as a 60-second heartbeat over the WS relay.
class NightModeState {
  final DayNight currentMode;
  final NightModeOverride override;
  final double? currentLux;
  final DateTime? lastChangedAt;

  /// When the app last received a state message — used by the provider to
  /// derive `isStale` (no heartbeat in 90+ seconds).
  final DateTime receivedAt;

  const NightModeState({
    required this.currentMode,
    required this.override,
    required this.currentLux,
    required this.lastChangedAt,
    required this.receivedAt,
  });

  /// Parse from a decoded `night_mode_state` JSON map. Returns null on a
  /// malformed message (missing/unknown mode or override).
  static NightModeState? fromJson(Map<String, dynamic> json) {
    final mode = DayNight.fromString(json['mode'] as String?);
    final override = NightModeOverride.fromString(json['override'] as String?);
    if (mode == null || override == null) return null;
    final luxRaw = json['lux'];
    final double? lux = luxRaw is num ? luxRaw.toDouble() : null;
    DateTime? lastChanged;
    final ts = json['last_changed_at'];
    if (ts is num) {
      lastChanged =
          DateTime.fromMillisecondsSinceEpoch((ts.toDouble() * 1000).round());
    } else if (ts is String) {
      lastChanged = DateTime.tryParse(ts);
    }
    return NightModeState(
      currentMode: mode,
      override: override,
      currentLux: lux,
      lastChangedAt: lastChanged,
      receivedAt: DateTime.now(),
    );
  }

  NightModeState copyWith({
    DayNight? currentMode,
    NightModeOverride? override,
    double? currentLux,
    DateTime? lastChangedAt,
    DateTime? receivedAt,
  }) {
    return NightModeState(
      currentMode: currentMode ?? this.currentMode,
      override: override ?? this.override,
      currentLux: currentLux ?? this.currentLux,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  /// Human-readable label for a lux reading. Thresholds are app-side only
  /// (robot decides actual day/night switching); see nightvision.md §3B.
  static String luxLabel(double? lux) {
    if (lux == null) return 'detecting…';
    if (lux < 5) return 'dark';
    if (lux < 15) return 'dim';
    if (lux < 100) return 'indoor lighting';
    if (lux < 1000) return 'well lit';
    return 'bright';
  }
}
