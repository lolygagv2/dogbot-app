import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/notification_event.dart';

/// Singleton service for OS-level local notifications.
/// Fires notifications when the app is backgrounded so events appear
/// on lock screen, notification center, and Apple Watch.
///
/// Per-type routing now lives in `AppSettings.channelFor(type)`. This service
/// no longer hard-codes the allow list; callers (notifications_provider) read
/// the channel from settings and decide whether to call [showForEvent].
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

  /// Deprecated — kept for source compatibility but always returns true.
  /// Routing decisions live in AppSettings.channelFor(type) now.
  @Deprecated('Read AppSettings.channelFor(type) instead')
  bool shouldNotify(NotificationEventType type) => true;

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
