// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MissionImpl _$$MissionImplFromJson(Map<String, dynamic> json) =>
    _$MissionImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetBehavior: json['targetBehavior'] as String? ?? 'sit',
      requiredDuration: (json['requiredDuration'] as num?)?.toDouble() ?? 3.0,
      cooldownSeconds: (json['cooldownSeconds'] as num?)?.toInt() ?? 15,
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 10,
      isActive: json['isActive'] as bool? ?? false,
      rewardsGiven: (json['rewardsGiven'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$MissionImplToJson(_$MissionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'targetBehavior': instance.targetBehavior,
      'requiredDuration': instance.requiredDuration,
      'cooldownSeconds': instance.cooldownSeconds,
      'dailyLimit': instance.dailyLimit,
      'isActive': instance.isActive,
      'rewardsGiven': instance.rewardsGiven,
      'progress': instance.progress,
    };

_$MissionProgressImpl _$$MissionProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$MissionProgressImpl(
      missionId: json['missionId'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      rewardsGiven: (json['rewardsGiven'] as num?)?.toInt() ?? 0,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      failCount: (json['failCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
    );

Map<String, dynamic> _$$MissionProgressImplToJson(
        _$MissionProgressImpl instance) =>
    <String, dynamic>{
      'missionId': instance.missionId,
      'progress': instance.progress,
      'rewardsGiven': instance.rewardsGiven,
      'successCount': instance.successCount,
      'failCount': instance.failCount,
      'status': instance.status,
      'startedAt': instance.startedAt?.toIso8601String(),
    };
