// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MissionScheduleImpl _$$MissionScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$MissionScheduleImpl(
      id: json['schedule_id'] as String,
      missionName: json['mission_name'] as String,
      dogId: json['dog_id'] as String,
      name: json['name'] as String? ?? '',
      type: $enumDecode(_$ScheduleTypeEnumMap, json['type']),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      daysOfWeek: (json['days_of_week'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      enabled: json['enabled'] as bool? ?? true,
      cooldownHours: (json['cooldown_hours'] as num?)?.toInt() ?? 24,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$MissionScheduleImplToJson(
        _$MissionScheduleImpl instance) =>
    <String, dynamic>{
      'schedule_id': instance.id,
      'mission_name': instance.missionName,
      'dog_id': instance.dogId,
      'name': instance.name,
      'type': _$ScheduleTypeEnumMap[instance.type]!,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'days_of_week': instance.daysOfWeek,
      'enabled': instance.enabled,
      'cooldown_hours': instance.cooldownHours,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$ScheduleTypeEnumMap = {
  ScheduleType.once: 'once',
  ScheduleType.daily: 'daily',
  ScheduleType.weekly: 'weekly',
};
