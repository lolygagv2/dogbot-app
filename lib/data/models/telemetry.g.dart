// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TelemetryImpl _$$TelemetryImplFromJson(Map<String, dynamic> json) =>
    _$TelemetryImpl(
      battery: (json['battery'] as num?)?.toDouble() ?? 0.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode'] as String? ?? 'idle',
      dogDetected: json['dogDetected'] as bool? ?? false,
      currentBehavior: json['currentBehavior'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isCharging: json['isCharging'] as bool? ?? false,
      treatsRemaining: (json['treatsRemaining'] as num?)?.toInt() ?? 0,
      lastTreatTime: json['lastTreatTime'] == null
          ? null
          : DateTime.parse(json['lastTreatTime'] as String),
      activeMissionId: json['activeMissionId'] as String?,
      rawData: json['rawData'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$TelemetryImplToJson(_$TelemetryImpl instance) =>
    <String, dynamic>{
      'battery': instance.battery,
      'temperature': instance.temperature,
      'mode': instance.mode,
      'dogDetected': instance.dogDetected,
      'currentBehavior': instance.currentBehavior,
      'confidence': instance.confidence,
      'isCharging': instance.isCharging,
      'treatsRemaining': instance.treatsRemaining,
      'lastTreatTime': instance.lastTreatTime?.toIso8601String(),
      'activeMissionId': instance.activeMissionId,
      'rawData': instance.rawData,
    };

_$DetectionImpl _$$DetectionImplFromJson(Map<String, dynamic> json) =>
    _$DetectionImpl(
      detected: json['detected'] as bool? ?? false,
      behavior: json['behavior'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      bbox: (json['bbox'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$DetectionImplToJson(_$DetectionImpl instance) =>
    <String, dynamic>{
      'detected': instance.detected,
      'behavior': instance.behavior,
      'confidence': instance.confidence,
      'bbox': instance.bbox,
      'timestamp': instance.timestamp?.toIso8601String(),
    };
