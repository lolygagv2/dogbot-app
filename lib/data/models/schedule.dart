import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

/// Schedule type for mission scheduling
enum ScheduleType {
  @JsonValue('once')
  once,
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
}

/// Mission schedule for automatic training sessions
@freezed
class MissionSchedule with _$MissionSchedule {
  const MissionSchedule._();

  const factory MissionSchedule({
    required String id,
    required String missionId,
    required String dogId,
    @Default('') String name,
    required ScheduleType type,
    required int hour,         // 0-23
    required int minute,       // 0-59
    @Default([]) List<int> weekdays,  // For weekly: 0=Sun, 1=Mon, ..., 6=Sat
    @Default(true) bool enabled,
    DateTime? nextRun,
  }) = _MissionSchedule;

  factory MissionSchedule.fromJson(Map<String, dynamic> json) =>
      _$MissionScheduleFromJson(json);

  /// Get formatted time string (e.g., "9:00 AM")
  String get timeString {
    final hourOfDay = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourOfDay:$minuteStr $period';
  }

  /// Get schedule description (e.g., "Daily at 9:00 AM")
  String get scheduleDescription {
    switch (type) {
      case ScheduleType.once:
        return 'Once at $timeString';
      case ScheduleType.daily:
        return 'Daily at $timeString';
      case ScheduleType.weekly:
        if (weekdays.isEmpty) return 'Weekly at $timeString';
        final dayNames = weekdays.map(_weekdayName).toList()..sort();
        if (dayNames.length == 7) return 'Every day at $timeString';
        return '${dayNames.join(", ")} at $timeString';
    }
  }

  /// Get short weekday name from number
  static String _weekdayName(int day) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[day.clamp(0, 6)];
  }

  /// Get next run display string
  String? get nextRunDisplay {
    if (nextRun == null) return null;
    final now = DateTime.now();
    final diff = nextRun!.difference(now);

    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }
}

/// State for the scheduler UI
class SchedulerState {
  final List<MissionSchedule> schedules;
  final bool isGlobalEnabled;
  final bool isLoading;
  final String? error;

  const SchedulerState({
    this.schedules = const [],
    this.isGlobalEnabled = true,
    this.isLoading = false,
    this.error,
  });

  SchedulerState copyWith({
    List<MissionSchedule>? schedules,
    bool? isGlobalEnabled,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SchedulerState(
      schedules: schedules ?? this.schedules,
      isGlobalEnabled: isGlobalEnabled ?? this.isGlobalEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Get schedules sorted by next run time
  List<MissionSchedule> get sortedSchedules {
    final sorted = List<MissionSchedule>.from(schedules);
    sorted.sort((a, b) {
      // Enabled schedules first
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      // Then by next run time
      if (a.nextRun == null && b.nextRun == null) return 0;
      if (a.nextRun == null) return 1;
      if (b.nextRun == null) return -1;
      return a.nextRun!.compareTo(b.nextRun!);
    });
    return sorted;
  }
}
