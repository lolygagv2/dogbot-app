import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_event.dart'
    show absolutizeAttachmentUrl, eventPhotoUrl;

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
  final String? dogId;
  final DateTime receivedAt;

  bool get hasMedia => imageUrl != null || clipUrl != null;

  /// Authenticated still endpoint for the push's event (null when the push
  /// has no still or names no event).
  String? get photoUrl =>
      imageUrl == null ? null : eventPhotoUrl(dogId, eventId);

  ForegroundPush({
    required this.title,
    required this.body,
    this.imageUrl,
    this.clipUrl,
    this.eventId,
    this.dogId,
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
    final dog = data['dog_id']?.toString();
    return ForegroundPush(
      title: t,
      body: b,
      imageUrl: absolutizeAttachmentUrl(data['image_url']) ??
          absolutizeAttachmentUrl(notificationImage),
      clipUrl: absolutizeAttachmentUrl(data['clip_url']),
      eventId: (event == null || event.isEmpty) ? null : event,
      dogId: (dog == null || dog.isEmpty) ? null : dog,
    );
  }
}

/// The banner currently on screen (null = none). Set by PushSync on a
/// foreground push; cleared by the banner on timeout / dismissal.
final foregroundPushProvider = StateProvider<ForegroundPush?>((ref) => null);

/// A tapped push (background / cold start) whose still / clip should open
/// in the viewer once the app has routed to the Events tab. Consumed by the
/// app shell.
final pushOpenMediaProvider = StateProvider<ForegroundPush?>((ref) => null);
