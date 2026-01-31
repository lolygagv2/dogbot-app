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

/// Day of week names (matching Robot API format)
class DayOfWeek {
  static const String sunday = 'sunday';
  static const String monday = 'monday';
  static const String tuesday = 'tuesday';
  static const String wednesday = 'wednesday';
  static const String thursday = 'thursday';
  static const String friday = 'friday';
  static const String saturday = 'saturday';

  static const List<String> all = [
    sunday, monday, tuesday, wednesday, thursday, friday, saturday
  ];

  /// Convert integer (0=Sun, 1=Mon, ...) to day name
  static String fromInt(int day) => all[day.clamp(0, 6)];

  /// Convert day name to integer
  static int toInt(String day) => all.indexOf(day.toLowerCase());

  /// Get short display name
  static String shortName(String day) {
    switch (day.toLowerCase()) {
      case sunday: return 'Sun';
      case monday: return 'Mon';
      case tuesday: return 'Tue';
      case wednesday: return 'Wed';
      case thursday: return 'Thu';
      case friday: return 'Fri';
      case saturday: return 'Sat';
      default: return day;
    }
  }
}

/// Mission schedule for automatic training sessions
/// Build 34: Updated to match Robot API format
@freezed
class MissionSchedule with _$MissionSchedule {
  const MissionSchedule._();

  const factory MissionSchedule({
    /// Schedule ID (robot uses schedule_id)
    @JsonKey(name: 'schedule_id') required String id,
    /// Mission name to run
    @JsonKey(name: 'mission_name') required String missionName,
    /// Dog ID this schedule is for
    @JsonKey(name: 'dog_id') required String dogId,
    /// Display name for the schedule
    @Default('') String name,
    /// Schedule type: once, daily, weekly
    required ScheduleType type,
    /// Start time in HH:MM format (e.g., "08:00")
    @JsonKey(name: 'start_time') required String startTime,
    /// End time in HH:MM format (e.g., "12:00")
    @JsonKey(name: 'end_time') required String endTime,
    /// Days of week as strings: ["monday", "tuesday", ...]
    @JsonKey(name: 'days_of_week') @Default([]) List<String> daysOfWeek,
    /// Whether schedule is enabled
    @Default(true) bool enabled,
    /// Hours between runs (cooldown)
    @JsonKey(name: 'cooldown_hours') @Default(24) int cooldownHours,
    /// Server-provided timestamps
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _MissionSchedule;

  factory MissionSchedule.fromJson(Map<String, dynamic> json) =>
      _$MissionScheduleFromJson(json);

  /// Get hour from startTime string
  int get hour {
    final parts = startTime.split(':');
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Get minute from startTime string
  int get minute {
    final parts = startTime.split(':');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  /// Get formatted time string (e.g., "9:00 AM")
  String get timeString {
    final h = hour;
    final hourOfDay = h % 12 == 0 ? 12 : h % 12;
    final period = h < 12 ? 'AM' : 'PM';
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
        if (daysOfWeek.isEmpty) return 'Weekly at $timeString';
        final dayNames = daysOfWeek.map(DayOfWeek.shortName).toList();
        if (dayNames.length == 7) return 'Every day at $timeString';
        return '${dayNames.join(", ")} at $timeString';
    }
  }

  /// Get next run display string
  String? get nextRunDisplay {
    // This would be computed from server data in the future
    return null;
  }

  /// Create time string from hour and minute
  static String timeFromHourMinute(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Convert weekday integers to day names
  static List<String> weekdaysToNames(List<int> weekdays) {
    return weekdays.map(DayOfWeek.fromInt).toList();
  }

  /// Convert day names to weekday integers
  static List<int> namesToWeekdays(List<String> names) {
    return names.map(DayOfWeek.toInt).where((i) => i >= 0).toList();
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

  /// Get schedules sorted by time
  List<MissionSchedule> get sortedSchedules {
    final sorted = List<MissionSchedule>.from(schedules);
    sorted.sort((a, b) {
      // Enabled schedules first
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      // Then by start time
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }
}
