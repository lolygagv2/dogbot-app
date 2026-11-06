import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/time_utils.dart';

part 'notification_event.freezed.dart';
part 'notification_event.g.dart';

/// Types of notification events from the WIM-Z robot
@JsonEnum(fieldRename: FieldRename.snake)
enum NotificationEventType {
  bark,
  sit,
  lieDown,
  stand,
  treatDispensed,
  missionStarted,
  missionCompleted,
  missionFailed,
  lowBattery,
  alert,
  happy,
  connected,
  disconnected,
  coachReward,
  // Robot 137a5e8 (2026-08-31): appended (never reorder — names feed relay
  // enabled_types and stored channel prefs)
  panicAlert, // panic_alert started/ended — distress episodes
  sgSummary, // sg_summary level4_escalation + guardian-stopped session summary
  // AI Summit demo slice (2026-11-05): an assistant drafted a mission and
  // wants the owner's approve/decline (metadata.draft_id → missionDraftsProvider)
  missionDraft,
}

/// A notification event from the robot
@freezed
class NotificationEvent with _$NotificationEvent {
  const factory NotificationEvent({
    required String id,
    required NotificationEventType type,
    required DateTime timestamp,
    required String title,
    String? subtitle,
    String? dogId,
    String? missionId,
    String? videoClipId,
    Map<String, dynamic>? metadata,
    @Default(false) bool isRead,
    /// Optional still (snapshot) attached by the robot/relay — absolute URL.
    String? imageUrl,
    /// Optional short clip attached by the robot/relay — absolute URL.
    String? clipUrl,
  }) = _NotificationEvent;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) =>
      _$NotificationEventFromJson(json);

  /// Create from WebSocket event data
  factory NotificationEvent.fromWsEvent(Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? 'alert';
    final type = NotificationEventType.values.firstWhere(
      (e) => e.name == typeStr || e.name == _snakeToCamel(typeStr),
      orElse: () => NotificationEventType.alert,
    );

    return NotificationEvent(
      id: data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: parseServerTimestamp(data['timestamp'] as String?),
      title: data['title'] as String? ?? _getDefaultTitle(type),
      subtitle: data['subtitle'] as String? ?? data['message'] as String?,
      dogId: data['dog_id'] as String?,
      missionId: data['mission_id'] as String?,
      videoClipId: data['video_clip_id'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      isRead: data['is_read'] as bool? ?? false,
      imageUrl: attachmentImageUrl(data),
      clipUrl: attachmentClipUrl(data),
    );
  }
}

/// Base URL used to absolutize relative attachment paths ("/media/x.jpg").
/// Set by DioClient.setBaseUrl; falls back to the production API host.
String attachmentBaseUrl = 'https://api.wimzai.com';

String? _absolutize(dynamic raw) {
  final s = raw?.toString();
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  final base = attachmentBaseUrl.endsWith('/')
      ? attachmentBaseUrl.substring(0, attachmentBaseUrl.length - 1)
      : attachmentBaseUrl;
  return s.startsWith('/') ? '$base$s' : '$base/$s';
}

/// Dig an attachment URL out of an event payload. The robot/relay may put it
/// at the top level or nested under data/payload/media; the key names vary
/// by event source, so accept the common spellings.
String? _digAttachment(Map<String, dynamic> data, List<String> keys) {
  String? pick(Map m) {
    for (final k in keys) {
      final v = _absolutize(m[k]);
      if (v != null) return v;
    }
    return null;
  }

  var url = pick(data);
  for (final nest in const ['data', 'payload', 'media', 'attachment']) {
    if (url != null) break;
    if (data[nest] is Map) url = pick(data[nest] as Map);
  }
  return url;
}

String? attachmentImageUrl(Map<String, dynamic> data) => _digAttachment(data,
    const ['image_url', 'snapshot_url', 'still_url', 'photo_url', 'thumbnail_url']);

String? attachmentClipUrl(Map<String, dynamic> data) => _digAttachment(
    data, const ['clip_url', 'video_url', 'mp4_url']);

String _snakeToCamel(String snake) {
  final parts = snake.split('_');
  if (parts.isEmpty) return snake;
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
}

String _getDefaultTitle(NotificationEventType type) {
  switch (type) {
    case NotificationEventType.bark:
      return 'Barking Detected';
    case NotificationEventType.sit:
      return 'Sitting Detected';
    case NotificationEventType.lieDown:
      return 'Lay Down';
    case NotificationEventType.stand:
      return 'Come';
    case NotificationEventType.treatDispensed:
      return 'Treat Dispensed';
    case NotificationEventType.missionStarted:
      return 'Mission Started';
    case NotificationEventType.missionCompleted:
      return 'Mission Completed';
    case NotificationEventType.missionFailed:
      return 'Mission Failed';
    case NotificationEventType.lowBattery:
      return 'Low Battery';
    case NotificationEventType.alert:
      return 'Alert';
    case NotificationEventType.happy:
      return 'Happy Dog';
    case NotificationEventType.connected:
      return 'Connected';
    case NotificationEventType.disconnected:
      return 'Disconnected';
    case NotificationEventType.coachReward:
      return 'Coach Reward';
    case NotificationEventType.panicAlert:
      return 'Panic Alert';
    case NotificationEventType.sgSummary:
      return 'Guardian Summary';
    case NotificationEventType.missionDraft:
      return 'Mission Approval';
  }
}
