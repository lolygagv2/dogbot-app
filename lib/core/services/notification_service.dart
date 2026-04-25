import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/notification_event.dart';

/// Singleton service for OS-level local notifications.
/// Fires notifications when the app is backgrounded so events appear
/// on lock screen, notification center, and Apple Watch.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Event types that should trigger a local notification.
  static const _notifiableTypes = {
    NotificationEventType.bark,
    NotificationEventType.treatDispensed,
    NotificationEventType.coachReward,
    NotificationEventType.missionCompleted,
    NotificationEventType.lowBattery,
    NotificationEventType.alert,
  };

  /// Initialize the plugin. Call once from main().
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Whether this event type should trigger a local notification.
  bool shouldNotify(NotificationEventType type) =>
      _notifiableTypes.contains(type);

  /// Whether the app is currently in the background.
  bool get isAppBackgrounded {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != AppLifecycleState.resumed;
  }

  /// Show a local notification for an activity event.
  Future<void> showForEvent(NotificationEvent event) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'wimz_activity',
        'WIM-Z Activity',
        channelDescription: 'Dog training activity notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      event.title,
      event.subtitle ?? '',
      details,
    );
  }
}
