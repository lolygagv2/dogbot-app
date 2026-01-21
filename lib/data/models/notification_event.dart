import 'package:freezed_annotation/freezed_annotation.dart';

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
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
      title: data['title'] as String? ?? _getDefaultTitle(type),
      subtitle: data['subtitle'] as String? ?? data['message'] as String?,
      dogId: data['dog_id'] as String?,
      missionId: data['mission_id'] as String?,
      videoClipId: data['video_clip_id'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      isRead: data['is_read'] as bool? ?? false,
    );
  }
}

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
      return 'Lying Down';
    case NotificationEventType.stand:
      return 'Standing';
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
  }
}
