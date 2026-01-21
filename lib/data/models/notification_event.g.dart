// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationEventImpl _$$NotificationEventImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationEventImpl(
      id: json['id'] as String,
      type: $enumDecode(_$NotificationEventTypeEnumMap, json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      dogId: json['dogId'] as String?,
      missionId: json['missionId'] as String?,
      videoClipId: json['videoClipId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
    );

Map<String, dynamic> _$$NotificationEventImplToJson(
        _$NotificationEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationEventTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'title': instance.title,
      'subtitle': instance.subtitle,
      'dogId': instance.dogId,
      'missionId': instance.missionId,
      'videoClipId': instance.videoClipId,
      'metadata': instance.metadata,
      'isRead': instance.isRead,
    };

const _$NotificationEventTypeEnumMap = {
  NotificationEventType.bark: 'bark',
  NotificationEventType.sit: 'sit',
  NotificationEventType.lieDown: 'lie_down',
  NotificationEventType.stand: 'stand',
  NotificationEventType.treatDispensed: 'treat_dispensed',
  NotificationEventType.missionStarted: 'mission_started',
  NotificationEventType.missionCompleted: 'mission_completed',
  NotificationEventType.missionFailed: 'mission_failed',
  NotificationEventType.lowBattery: 'low_battery',
  NotificationEventType.alert: 'alert',
  NotificationEventType.happy: 'happy',
  NotificationEventType.connected: 'connected',
  NotificationEventType.disconnected: 'disconnected',
};
