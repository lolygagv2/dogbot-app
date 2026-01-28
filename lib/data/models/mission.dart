import 'package:freezed_annotation/freezed_annotation.dart';

part 'mission.freezed.dart';
part 'mission.g.dart';

/// Training mission configuration
@freezed
class Mission with _$Mission {
  const factory Mission({
    required String id,
    required String name,
    String? description,
    @Default('sit') String targetBehavior,
    @Default(3.0) double requiredDuration,
    @Default(15) int cooldownSeconds,
    @Default(10) int dailyLimit,
    @Default(false) bool isActive,
    @Default(0) int rewardsGiven,
    @Default(0.0) double progress,
  }) = _Mission;

  factory Mission.fromJson(Map<String, dynamic> json) =>
      _$MissionFromJson(json);
}

/// Mission progress update from WebSocket
@freezed
class MissionProgress with _$MissionProgress {
  const MissionProgress._();

  const factory MissionProgress({
    required String missionId,
    @Default(0.0) double progress,
    @Default(0) int rewardsGiven,
    @Default(0) int successCount,
    @Default(0) int failCount,
    String? status,
    DateTime? startedAt,
    String? stage,
    String? trick,
    double? targetSec,
    double? holdTime,
    String? reason,
  }) = _MissionProgress;

  factory MissionProgress.fromJson(Map<String, dynamic> json) =>
      _$MissionProgressFromJson(json);

  factory MissionProgress.fromWsEvent(Map<String, dynamic> data) {
    return MissionProgress(
      missionId: data['id'] as String? ?? data['mission_id'] as String? ?? '',
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      rewardsGiven: data['rewards_given'] as int? ?? 0,
      successCount: data['success_count'] as int? ?? 0,
      failCount: data['fail_count'] as int? ?? 0,
      status: data['status'] as String?,
      stage: data['stage'] as String?,
      trick: data['trick'] as String?,
      targetSec: (data['target_sec'] as num?)?.toDouble(),
      holdTime: (data['hold_time'] as num?)?.toDouble(),
      reason: data['reason'] as String?,
    );
  }

  /// Compute effective progress: if progress and targetSec are both present,
  /// use (progress / targetSec).clamp(0.0, 1.0)
  double get effectiveProgress {
    if (targetSec != null && targetSec! > 0 && progress > 0) {
      return (progress / targetSec!).clamp(0.0, 1.0);
    }
    return progress.clamp(0.0, 1.0);
  }
}
