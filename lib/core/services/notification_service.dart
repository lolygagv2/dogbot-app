import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/notification_event.dart';
import '../utils/conn_trace.dart';

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
  ///
  /// [channelName]/[channelDescription] are the user-visible Android channel
  /// strings; the caller (notifications_provider) passes localized ones.
  Future<void> showForEvent(
    NotificationEvent event, {
    String? channelName,
    String? channelDescription,
  }) async {
    if (!_initialized) return;

    // Still attached by the robot/relay → lock-screen image (best effort:
    // a slow or failed download just means a text-only banner).
    final imagePath = await _cacheAttachment(event.imageUrl);
    final body = event.subtitle ?? '';

    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: imagePath != null
            ? [DarwinNotificationAttachment(imagePath)]
            : null,
      ),
      android: AndroidNotificationDetails(
        'wimz_activity',
        channelName ?? 'WIM-Z Activity',
        channelDescription:
            channelDescription ?? 'Dog training activity notifications',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: imagePath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                contentTitle: event.title,
                summaryText: body,
              )
            : null,
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      event.title,
      body,
      details,
    );
  }

  /// Download an attachment to the temp dir; null when unavailable. Capped
  /// at 4s so a dead media host never delays the banner noticeably.
  Future<String?> _cacheAttachment(String? url) async {
    if (url == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final ext = url.toLowerCase().contains('.png') ? 'png' : 'jpg';
      final file = File(
          '${dir.path}/wimz_notif_${DateTime.now().millisecondsSinceEpoch}.$ext');
      final r = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      if (r.data == null || r.data!.isEmpty) return null;
      await file.writeAsBytes(r.data!);
      return file.path;
    } catch (e) {
      connTrace('notif-attachment-error', '$e');
      return null;
    }
  }
}
