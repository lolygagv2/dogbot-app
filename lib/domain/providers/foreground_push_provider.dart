import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_event.dart' show absolutizeAttachmentUrl;

/// A relay push that arrived while the app was in the foreground, shown as
/// an in-app banner (the OS shows none in that state).
///
/// Relay payload (notify_service): `notification {title, body, image?}` +
/// `data {type, dog_id, event_id, rule_id, image_url, clip_url}` — the data
/// URLs are relay-relative ("" when the rule attaches nothing).
class ForegroundPush {
  final String title;
  final String body;
  final String? imageUrl;
  final String? clipUrl;
  final String? eventId;
  final DateTime receivedAt;

  ForegroundPush({
    required this.title,
    required this.body,
    this.imageUrl,
    this.clipUrl,
    this.eventId,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Null when there is nothing to show (a data-only message).
  /// [notificationImage] is the absolute image FCM carries on the
  /// notification itself; `data.image_url` wins when both are present.
  static ForegroundPush? fromParts({
    String? title,
    String? body,
    String? notificationImage,
    Map<String, dynamic> data = const {},
  }) {
    final t = (title ?? data['title']?.toString() ?? '').trim();
    final b = (body ?? data['body']?.toString() ?? '').trim();
    if (t.isEmpty && b.isEmpty) return null;
    final event = data['event_id']?.toString();
    return ForegroundPush(
      title: t,
      body: b,
      imageUrl: absolutizeAttachmentUrl(data['image_url']) ??
          absolutizeAttachmentUrl(notificationImage),
      clipUrl: absolutizeAttachmentUrl(data['clip_url']),
      eventId: (event == null || event.isEmpty) ? null : event,
    );
  }
}

/// The banner currently on screen (null = none). Set by PushSync on a
/// foreground push; cleared by the banner on timeout / dismissal.
final foregroundPushProvider = StateProvider<ForegroundPush?>((ref) => null);
