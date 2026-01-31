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

/// Mission status values from Build 31 coach flow
enum MissionStatus {
  waitingForDog('waiting_for_dog', 'Waiting for dog...'),
  greeting('greeting', 'Greeting...'),
  command('command', 'Commanding'),
  watching('watching', 'Hold it...'),
  success('success', 'Success!'),
  failed('failed', 'Try again'),
  retry('retry', 'Trying again...'),
  completed('completed', 'Complete!'),
  stopped('stopped', 'Stopped'),
  unknown('unknown', '');

  final String value;
  final String label;
  const MissionStatus(this.value, this.label);

  static MissionStatus fromString(String? value) {
    if (value == null) return MissionStatus.unknown;
    return MissionStatus.values.firstWhere(
      (s) => s.value == value.toLowerCase(),
      orElse: () => MissionStatus.unknown,
    );
  }

  bool get isActive => this != stopped && this != completed && this != unknown;
  bool get showsProgress => this == watching;
  bool get isSuccess => this == success || this == completed;
  bool get isFailure => this == failed;
}

/// Mission progress update from WebSocket (Build 31 format)
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
    // Build 31 fields
    String? trick,
    double? targetSec,
    double? holdTime,
    String? reason,
    int? stageNumber,      // Current stage (1-based)
    int? totalStages,      // Total stages in mission
    String? dogName,       // Dog being trained
    // Build 32 fields
    String? missionName,   // Human-readable mission name from robot
  }) = _MissionProgress;

  factory MissionProgress.fromJson(Map<String, dynamic> json) =>
      _$MissionProgressFromJson(json);

  factory MissionProgress.fromWsEvent(Map<String, dynamic> data) {
    return MissionProgress(
      missionId: data['id'] as String? ?? data['mission_id'] as String? ?? '',
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      rewardsGiven: data['rewards'] as int? ?? data['rewards_given'] as int? ?? 0,
      successCount: data['success_count'] as int? ?? 0,
      failCount: data['fail_count'] as int? ?? 0,
      status: data['status'] as String?,
      trick: data['trick'] as String?,
      targetSec: (data['target_sec'] as num?)?.toDouble(),
      holdTime: (data['hold_time'] as num?)?.toDouble(),
      reason: data['reason'] as String?,
      stageNumber: data['stage'] as int?,
      totalStages: data['total_stages'] as int?,
      dogName: data['dog_name'] as String?,
      missionName: data['mission_name'] as String?,  // Build 32: from robot
    );
  }

  /// Get typed status enum
  MissionStatus get statusEnum => MissionStatus.fromString(status);

  /// Compute effective progress: if progress and targetSec are both present,
  /// use (progress / targetSec).clamp(0.0, 1.0)
  double get effectiveProgress {
    if (targetSec != null && targetSec! > 0 && progress > 0) {
      return (progress / targetSec!).clamp(0.0, 1.0);
    }
    return progress.clamp(0.0, 1.0);
  }

  /// Stage display string (e.g., "Stage 2 of 5")
  String? get stageDisplay {
    if (stageNumber == null || totalStages == null) return null;
    return 'Stage $stageNumber of $totalStages';
  }

  /// Status display with dog name
  String get statusDisplay {
    final statusLabel = statusEnum.label;
    if (dogName != null && statusEnum == MissionStatus.waitingForDog) {
      return 'Waiting for $dogName...';
    }
    if (dogName != null && statusEnum == MissionStatus.greeting) {
      return 'Greeting $dogName...';
    }
    if (trick != null && statusEnum == MissionStatus.command) {
      return '${trick!.toUpperCase()}!';
    }
    return statusLabel;
  }
}

/// Mission history entry for tracking past training sessions
@freezed
class MissionHistoryEntry with _$MissionHistoryEntry {
  const factory MissionHistoryEntry({
    required String id,
    required String missionId,
    required String missionName,
    required String dogId,
    required DateTime startedAt,
    DateTime? completedAt,
    @Default(0) int treatsGiven,
    @Default(0) int stagesCompleted,
    @Default(0) int totalStages,
    @Default(false) bool wasCompleted,
  }) = _MissionHistoryEntry;

  factory MissionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$MissionHistoryEntryFromJson(json);
}

/// Mission statistics for a dog
@freezed
class MissionStats with _$MissionStats {
  const MissionStats._();

  const factory MissionStats({
    required String dogId,
    @Default(0) int totalMissions,
    @Default(0) int completedMissions,
    @Default(0) int totalTreats,
    @Default(0.0) double successRate,
    @Default({}) Map<String, int> missionCounts,
  }) = _MissionStats;

  factory MissionStats.fromJson(Map<String, dynamic> json) =>
      _$MissionStatsFromJson(json);

  /// Success rate as percentage string
  String get successRatePercent => '${(successRate * 100).toInt()}%';
}
