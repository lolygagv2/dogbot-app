// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DogProfileImpl _$$DogProfileImplFromJson(Map<String, dynamic> json) =>
    _$DogProfileImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      breed: json['breed'] as String?,
      photoUrl: json['photoUrl'] as String?,
      localPhotoPath: json['localPhotoPath'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      color: $enumDecodeNullable(_$DogColorEnumMap, json['color']) ??
          DogColor.mixed,
      arucoMarkerId: (json['arucoMarkerId'] as num?)?.toInt(),
      goals:
          (json['goals'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      lastMissionId: json['lastMissionId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      photoVersion: (json['photoVersion'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DogProfileImplToJson(_$DogProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'breed': instance.breed,
      'photoUrl': instance.photoUrl,
      'localPhotoPath': instance.localPhotoPath,
      'birthDate': instance.birthDate?.toIso8601String(),
      'weight': instance.weight,
      'notes': instance.notes,
      'color': _$DogColorEnumMap[instance.color]!,
      'arucoMarkerId': instance.arucoMarkerId,
      'goals': instance.goals,
      'lastMissionId': instance.lastMissionId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'photoVersion': instance.photoVersion,
    };

const _$DogColorEnumMap = {
  DogColor.black: 'black',
  DogColor.yellow: 'yellow',
  DogColor.brown: 'brown',
  DogColor.white: 'white',
  DogColor.mixed: 'mixed',
};

_$DogDailySummaryImpl _$$DogDailySummaryImplFromJson(
        Map<String, dynamic> json) =>
    _$DogDailySummaryImpl(
      dogId: json['dogId'] as String,
      date: DateTime.parse(json['date'] as String),
      treatCount: (json['treatCount'] as num?)?.toInt() ?? 0,
      sitCount: (json['sitCount'] as num?)?.toInt() ?? 0,
      barkCount: (json['barkCount'] as num?)?.toInt() ?? 0,
      goalProgress: (json['goalProgress'] as num?)?.toDouble() ?? 0.0,
      missionCount: (json['missionCount'] as num?)?.toInt() ?? 0,
      missionSuccessCount: (json['missionSuccessCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DogDailySummaryImplToJson(
        _$DogDailySummaryImpl instance) =>
    <String, dynamic>{
      'dogId': instance.dogId,
      'date': instance.date.toIso8601String(),
      'treatCount': instance.treatCount,
      'sitCount': instance.sitCount,
      'barkCount': instance.barkCount,
      'goalProgress': instance.goalProgress,
      'missionCount': instance.missionCount,
      'missionSuccessCount': instance.missionSuccessCount,
    };
