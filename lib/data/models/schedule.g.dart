// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MissionScheduleImpl _$$MissionScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$MissionScheduleImpl(
      id: json['id'] as String,
      missionId: json['missionId'] as String,
      dogId: json['dogId'] as String,
      name: json['name'] as String? ?? '',
      type: $enumDecode(_$ScheduleTypeEnumMap, json['type']),
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      weekdays: (json['weekdays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      enabled: json['enabled'] as bool? ?? true,
      nextRun: json['nextRun'] == null
          ? null
          : DateTime.parse(json['nextRun'] as String),
    );

Map<String, dynamic> _$$MissionScheduleImplToJson(
        _$MissionScheduleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'missionId': instance.missionId,
      'dogId': instance.dogId,
      'name': instance.name,
      'type': _$ScheduleTypeEnumMap[instance.type]!,
      'hour': instance.hour,
      'minute': instance.minute,
      'weekdays': instance.weekdays,
      'enabled': instance.enabled,
      'nextRun': instance.nextRun?.toIso8601String(),
    };

const _$ScheduleTypeEnumMap = {
  ScheduleType.once: 'once',
  ScheduleType.daily: 'daily',
  ScheduleType.weekly: 'weekly',
};
