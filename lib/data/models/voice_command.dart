import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_command.freezed.dart';
part 'voice_command.g.dart';

/// Predefined voice command types
enum VoiceCommandType {
  name('name', 'Dog\'s Name', 'Say your dog\'s name clearly'),
  sit('sit', 'Sit', 'Say "Sit" firmly'),
  stay('stay', 'Stay', 'Say "Stay" with a steady tone'),
  lieDown('lie_down', 'Lie Down', 'Say "Lie Down" or "Down"'),
  spin('spin', 'Spin', 'Say "Spin" enthusiastically'),
  come('come', 'Come', 'Say "Come" or "Come here"'),
  treat('treat', 'Want a treat?', 'Say "Want a treat?" playfully'),
  goodDog('good_dog', 'Good dog!', 'Say "Good dog!" with praise'),
  no('no', 'No / Bad', 'Say "No" or "Bad" firmly');

  final String id;
  final String label;
  final String prompt;
  const VoiceCommandType(this.id, this.label, this.prompt);

  static VoiceCommandType fromId(String id) {
    return VoiceCommandType.values.firstWhere(
      (c) => c.id == id,
      orElse: () => VoiceCommandType.name,
    );
  }
}

/// A recorded voice command for a specific dog
@freezed
class VoiceCommand with _$VoiceCommand {
  const factory VoiceCommand({
    required String dogId,
    required String commandId,
    String? localPath,
    DateTime? recordedAt,
    @Default(false) bool isSynced,
    DateTime? syncedAt,
    @Default(0) int durationMs,
  }) = _VoiceCommand;

  factory VoiceCommand.fromJson(Map<String, dynamic> json) =>
      _$VoiceCommandFromJson(json);
}

/// Voice commands state for a dog
@freezed
class DogVoiceCommands with _$DogVoiceCommands {
  const factory DogVoiceCommands({
    required String dogId,
    @Default({}) Map<String, VoiceCommand> commands,
    @Default(false) bool isRecording,
    String? currentRecordingCommand,
  }) = _DogVoiceCommands;

  factory DogVoiceCommands.fromJson(Map<String, dynamic> json) =>
      _$DogVoiceCommandsFromJson(json);
}
