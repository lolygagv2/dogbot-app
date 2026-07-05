import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/notification_event.dart';
import 'video_quality_provider.dart';

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
  static const notificationsEnabled = 'notifications_enabled';
  static const notificationChannels = 'notification_channels_v1';
  static const videoQualityMode = 'video_quality_mode';
}

/// Per-event-type destination for a notification:
/// - [off]: suppress entirely (not even the in-app feed)
/// - [inApp]: add to the in-app activity feed only — never wakes the lock
///   screen / Apple Watch
/// - [inAppAndPush]: in-app feed AND OS-level local notification (which iOS
///   mirrors to Apple Watch automatically)
enum NotificationChannel { off, inApp, inAppAndPush }

/// Defaults — chosen so high-frequency / low-value events stay quiet.
/// Override per type via the settings screen.
const Map<NotificationEventType, NotificationChannel> _defaultChannels = {
  // High-signal: always OS push (Watch + lock screen)
  NotificationEventType.treatDispensed: NotificationChannel.inAppAndPush,
  NotificationEventType.coachReward: NotificationChannel.inAppAndPush,
  NotificationEventType.missionCompleted: NotificationChannel.inAppAndPush,
  NotificationEventType.alert: NotificationChannel.inAppAndPush,
  NotificationEventType.lowBattery: NotificationChannel.inAppAndPush,
  // Medium-signal: in-app feed only by default (chatty if pushed)
  NotificationEventType.bark: NotificationChannel.inApp,
  NotificationEventType.missionFailed: NotificationChannel.inApp,
  NotificationEventType.happy: NotificationChannel.inApp,
  // Behavior detections — confidence noise; in-app only
  NotificationEventType.sit: NotificationChannel.inApp,
  NotificationEventType.lieDown: NotificationChannel.inApp,
  NotificationEventType.stand: NotificationChannel.inApp,
  // Connection events — off; not user-actionable
  NotificationEventType.connected: NotificationChannel.off,
  NotificationEventType.disconnected: NotificationChannel.off,
  NotificationEventType.missionStarted: NotificationChannel.inApp,
};

NotificationChannel defaultChannelFor(NotificationEventType type) =>
    _defaultChannels[type] ?? NotificationChannel.inApp;

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

  /// Local notifications — global on/off for OS notifications when backgrounded
  final bool notificationsEnabled;

  /// Per-event-type routing. Missing keys fall back to defaults.
  final Map<NotificationEventType, NotificationChannel> notificationChannels;

  /// User's video-quality override. `auto` lets the robot's adaptive
  /// controller pick the tier; the others pin it. Persisted app-wide.
  final VideoQualityMode videoQualityMode;

  const AppSettings({
    this.motorTrimRight = 0.0,
    this.cameraTrackingEnabled = false,
    this.backgroundAudioEnabled = true,
    this.dailyLimitEnabled = false,
    this.dailyLimitCount = 30,
    this.localModeEnabled = false,
    this.localModeIp = '',
    this.localModePort = 8000,
    this.notificationsEnabled = true,
    this.notificationChannels = const {},
    this.videoQualityMode = VideoQualityMode.auto,
  });

  /// Resolve the channel for an event type, applying defaults for missing keys.
  NotificationChannel channelFor(NotificationEventType type) =>
      notificationChannels[type] ?? defaultChannelFor(type);

  AppSettings copyWith({
    double? motorTrimRight,
    bool? cameraTrackingEnabled,
    bool? backgroundAudioEnabled,
    bool? dailyLimitEnabled,
    int? dailyLimitCount,
    bool? localModeEnabled,
    String? localModeIp,
    int? localModePort,
    bool? notificationsEnabled,
    Map<NotificationEventType, NotificationChannel>? notificationChannels,
    VideoQualityMode? videoQualityMode,
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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationChannels: notificationChannels ?? this.notificationChannels,
      videoQualityMode: videoQualityMode ?? this.videoQualityMode,
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
  late final Future<void> _initialized;

  SettingsNotifier(this._ref) : super(const AppSettings()) {
    _initialized = _loadSettings();
  }

  /// Completes once persisted settings have been read from disk. Until then
  /// every field is the compile-time default (localModeEnabled=false), which
  /// callers must not treat as the user's real choice.
  Future<void> get ready => _initialized;

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
    final notificationsEnabled = _prefs?.getBool(SettingsKeys.notificationsEnabled) ?? true;
    final videoQualityMode = VideoQualityMode.fromName(
        _prefs?.getString(SettingsKeys.videoQualityMode));

    // Channels persisted as JSON map of {eventTypeName: channelName}.
    final channelsJson = _prefs?.getString(SettingsKeys.notificationChannels);
    final channels = <NotificationEventType, NotificationChannel>{};
    if (channelsJson != null && channelsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(channelsJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final type = NotificationEventType.values.firstWhere(
            (t) => t.name == entry.key,
            orElse: () => NotificationEventType.alert,
          );
          final channel = NotificationChannel.values.firstWhere(
            (c) => c.name == entry.value,
            orElse: () => NotificationChannel.inApp,
          );
          channels[type] = channel;
        }
      } catch (e) {
        print('Settings: Failed to load notification channels: $e');
      }
    }

    state = AppSettings(
      motorTrimRight: motorTrim.clamp(-0.5, 0.5),
      cameraTrackingEnabled: cameraTracking,
      backgroundAudioEnabled: backgroundAudio,
      dailyLimitEnabled: dailyLimitEnabled,
      dailyLimitCount: dailyLimitCount.clamp(1, 200),
      localModeEnabled: localModeEnabled,
      localModeIp: localModeIp,
      localModePort: localModePort,
      notificationsEnabled: notificationsEnabled,
      notificationChannels: channels,
      videoQualityMode: videoQualityMode,
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

  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs?.setBool(SettingsKeys.notificationsEnabled, enabled);
    print('Settings: Notifications set to $enabled');
  }

  /// Set the channel for a single event type.
  Future<void> setNotificationChannel(
    NotificationEventType type,
    NotificationChannel channel,
  ) async {
    final next = Map<NotificationEventType, NotificationChannel>.from(
        state.notificationChannels);
    next[type] = channel;
    state = state.copyWith(notificationChannels: next);
    await _persistChannels();
  }

  /// Reset all notification channels to defaults.
  Future<void> resetNotificationChannels() async {
    state = state.copyWith(notificationChannels: const {});
    await _prefs?.remove(SettingsKeys.notificationChannels);
  }

  Future<void> _persistChannels() async {
    final encoded = <String, String>{
      for (final entry in state.notificationChannels.entries)
        entry.key.name: entry.value.name,
    };
    await _prefs?.setString(
      SettingsKeys.notificationChannels,
      jsonEncode(encoded),
    );
  }

  /// Set the video-quality override mode and tell the robot.
  /// 'auto' releases the robot's adaptive controller; 'low'/'medium'/'high'
  /// pin the tier. The selection is persisted so it survives app restarts.
  Future<void> setVideoQualityMode(VideoQualityMode mode) async {
    state = state.copyWith(videoQualityMode: mode);
    await _prefs?.setString(SettingsKeys.videoQualityMode, mode.name);
    _ref.read(websocketClientProvider).sendVideoQualityMode(mode.name);
    print('Settings: Video quality mode set to ${mode.name}');
  }

  /// Toggle local mode on/off
  Future<void> setLocalModeEnabled(bool enabled) async {
    // Wait for _loadSettings: called earlier, _prefs could still be null (the
    // persist would silently no-op) and the late state assignment in
    // _loadSettings would clobber this flag back to the stale disk value —
    // flipping the dog-profile storage scope mid-session.
    await _initialized;
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
