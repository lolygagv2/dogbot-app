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
      trick: json['trick'] as String?,
      targetSec: (json['targetSec'] as num?)?.toDouble(),
      holdTime: (json['holdTime'] as num?)?.toDouble(),
      reason: json['reason'] as String?,
      stageNumber: (json['stageNumber'] as num?)?.toInt(),
      totalStages: (json['totalStages'] as num?)?.toInt(),
      dogName: json['dogName'] as String?,
      missionName: json['missionName'] as String?,
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
      'trick': instance.trick,
      'targetSec': instance.targetSec,
      'holdTime': instance.holdTime,
      'reason': instance.reason,
      'stageNumber': instance.stageNumber,
      'totalStages': instance.totalStages,
      'dogName': instance.dogName,
      'missionName': instance.missionName,
    };

_$MissionHistoryEntryImpl _$$MissionHistoryEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$MissionHistoryEntryImpl(
      id: json['id'] as String,
      missionId: json['missionId'] as String,
      missionName: json['missionName'] as String,
      dogId: json['dogId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      treatsGiven: (json['treatsGiven'] as num?)?.toInt() ?? 0,
      stagesCompleted: (json['stagesCompleted'] as num?)?.toInt() ?? 0,
      totalStages: (json['totalStages'] as num?)?.toInt() ?? 0,
      wasCompleted: json['wasCompleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$MissionHistoryEntryImplToJson(
        _$MissionHistoryEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'missionId': instance.missionId,
      'missionName': instance.missionName,
      'dogId': instance.dogId,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'treatsGiven': instance.treatsGiven,
      'stagesCompleted': instance.stagesCompleted,
      'totalStages': instance.totalStages,
      'wasCompleted': instance.wasCompleted,
    };

_$MissionStatsImpl _$$MissionStatsImplFromJson(Map<String, dynamic> json) =>
    _$MissionStatsImpl(
      dogId: json['dogId'] as String,
      totalMissions: (json['totalMissions'] as num?)?.toInt() ?? 0,
      completedMissions: (json['completedMissions'] as num?)?.toInt() ?? 0,
      totalTreats: (json['totalTreats'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0.0,
      missionCounts: (json['missionCounts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
    );

Map<String, dynamic> _$$MissionStatsImplToJson(_$MissionStatsImpl instance) =>
    <String, dynamic>{
      'dogId': instance.dogId,
      'totalMissions': instance.totalMissions,
      'completedMissions': instance.completedMissions,
      'totalTreats': instance.totalTreats,
      'successRate': instance.successRate,
      'missionCounts': instance.missionCounts,
    };
