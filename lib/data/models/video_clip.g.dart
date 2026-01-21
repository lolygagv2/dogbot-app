// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VideoClipImpl _$$VideoClipImplFromJson(Map<String, dynamic> json) =>
    _$VideoClipImpl(
      id: json['id'] as String,
      url: json['url'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      dogId: json['dogId'] as String?,
      missionId: json['missionId'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => VideoEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      isShared: json['isShared'] as bool? ?? false,
    );

Map<String, dynamic> _$$VideoClipImplToJson(_$VideoClipImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'timestamp': instance.timestamp.toIso8601String(),
      'duration': instance.duration.inMicroseconds,
      'thumbnailUrl': instance.thumbnailUrl,
      'dogId': instance.dogId,
      'missionId': instance.missionId,
      'tags': instance.tags,
      'events': instance.events,
      'isFavorite': instance.isFavorite,
      'isShared': instance.isShared,
    };

_$VideoEventImpl _$$VideoEventImplFromJson(Map<String, dynamic> json) =>
    _$VideoEventImpl(
      timestamp: Duration(microseconds: (json['timestamp'] as num).toInt()),
      type: json['type'] as String,
      label: json['label'] as String?,
    );

Map<String, dynamic> _$$VideoEventImplToJson(_$VideoEventImpl instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.inMicroseconds,
      'type': instance.type,
      'label': instance.label,
    };
