import 'package:freezed_annotation/freezed_annotation.dart';

part 'program.freezed.dart';
part 'program.g.dart';

/// Training program - a sequence of missions with rest periods
@freezed
class Program with _$Program {
  const Program._();

  const factory Program({
    required String id,
    required String name,
    required String description,
    required List<String> missionIds,
    @Default(30) int restSecondsBetween,
    @Default(0) int currentMissionIndex,
    @Default(false) bool isActive,
    String? iconName,
  }) = _Program;

  factory Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);

  /// Whether program is complete
  bool get isComplete => currentMissionIndex >= missionIds.length;

  /// Total number of missions
  int get totalMissions => missionIds.length;

  /// Current mission ID (null if complete)
  String? get currentMissionId =>
      currentMissionIndex < missionIds.length ? missionIds[currentMissionIndex] : null;

  /// Progress as fraction (0.0 - 1.0)
  double get progress =>
      missionIds.isEmpty ? 0.0 : currentMissionIndex / missionIds.length;
}

/// Program progress update from WebSocket
@freezed
class ProgramProgress with _$ProgramProgress {
  const ProgramProgress._();

  const factory ProgramProgress({
    required String programId,
    @Default(0) int currentMissionIndex,
    @Default(0) int totalMissions,
    @Default(false) bool isResting,
    @Default(0) int restSecondsRemaining,
    String? currentMissionId,
    String? status,
  }) = _ProgramProgress;

  factory ProgramProgress.fromJson(Map<String, dynamic> json) =>
      _$ProgramProgressFromJson(json);

  factory ProgramProgress.fromWsEvent(Map<String, dynamic> data) {
    return ProgramProgress(
      programId: data['program_id'] as String? ?? '',
      currentMissionIndex: data['current_mission_index'] as int? ?? 0,
      totalMissions: data['total_missions'] as int? ?? 0,
      isResting: data['is_resting'] as bool? ?? false,
      restSecondsRemaining: data['rest_seconds_remaining'] as int? ?? 0,
      currentMissionId: data['current_mission_id'] as String?,
      status: data['status'] as String?,
    );
  }

  /// Progress as fraction
  double get progress =>
      totalMissions == 0 ? 0.0 : currentMissionIndex / totalMissions;

  /// Human-readable status
  String get statusDisplay {
    if (isResting) {
      return 'Resting... ${restSecondsRemaining}s';
    }
    if (status == 'completed') {
      return 'Program Complete!';
    }
    return 'Mission ${currentMissionIndex + 1} of $totalMissions';
  }
}
