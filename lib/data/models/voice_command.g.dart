// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VoiceCommandImpl _$$VoiceCommandImplFromJson(Map<String, dynamic> json) =>
    _$VoiceCommandImpl(
      dogId: json['dogId'] as String,
      commandId: json['commandId'] as String,
      localPath: json['localPath'] as String?,
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.parse(json['recordedAt'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      syncedAt: json['syncedAt'] == null
          ? null
          : DateTime.parse(json['syncedAt'] as String),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$VoiceCommandImplToJson(_$VoiceCommandImpl instance) =>
    <String, dynamic>{
      'dogId': instance.dogId,
      'commandId': instance.commandId,
      'localPath': instance.localPath,
      'recordedAt': instance.recordedAt?.toIso8601String(),
      'isSynced': instance.isSynced,
      'syncedAt': instance.syncedAt?.toIso8601String(),
      'durationMs': instance.durationMs,
    };

_$DogVoiceCommandsImpl _$$DogVoiceCommandsImplFromJson(
        Map<String, dynamic> json) =>
    _$DogVoiceCommandsImpl(
      dogId: json['dogId'] as String,
      commands: (json['commands'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, VoiceCommand.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
      isRecording: json['isRecording'] as bool? ?? false,
      currentRecordingCommand: json['currentRecordingCommand'] as String?,
    );

Map<String, dynamic> _$$DogVoiceCommandsImplToJson(
        _$DogVoiceCommandsImpl instance) =>
    <String, dynamic>{
      'dogId': instance.dogId,
      'commands': instance.commands,
      'isRecording': instance.isRecording,
      'currentRecordingCommand': instance.currentRecordingCommand,
    };
