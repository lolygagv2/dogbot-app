// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProgramImpl _$$ProgramImplFromJson(Map<String, dynamic> json) =>
    _$ProgramImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      missionIds: (json['missionIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      restSecondsBetween: (json['restSecondsBetween'] as num?)?.toInt() ?? 30,
      currentMissionIndex: (json['currentMissionIndex'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      iconName: json['iconName'] as String?,
    );

Map<String, dynamic> _$$ProgramImplToJson(_$ProgramImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'missionIds': instance.missionIds,
      'restSecondsBetween': instance.restSecondsBetween,
      'currentMissionIndex': instance.currentMissionIndex,
      'isActive': instance.isActive,
      'iconName': instance.iconName,
    };

_$ProgramProgressImpl _$$ProgramProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$ProgramProgressImpl(
      programId: json['programId'] as String,
      currentMissionIndex: (json['currentMissionIndex'] as num?)?.toInt() ?? 0,
      totalMissions: (json['totalMissions'] as num?)?.toInt() ?? 0,
      isResting: json['isResting'] as bool? ?? false,
      restSecondsRemaining:
          (json['restSecondsRemaining'] as num?)?.toInt() ?? 0,
      currentMissionId: json['currentMissionId'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$$ProgramProgressImplToJson(
        _$ProgramProgressImpl instance) =>
    <String, dynamic>{
      'programId': instance.programId,
      'currentMissionIndex': instance.currentMissionIndex,
      'totalMissions': instance.totalMissions,
      'isResting': instance.isResting,
      'restSecondsRemaining': instance.restSecondsRemaining,
      'currentMissionId': instance.currentMissionId,
      'status': instance.status,
    };
