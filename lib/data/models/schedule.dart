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
    /// Relay brief 2026-11-07: entries the robot mirrors from the relay's
    /// `missions` setting carry `mission_type` (training type, or a mode:
    /// silent_guardian / coach) and `source: "relay_settings"`.
    @JsonKey(name: 'mission_type') String? missionType,
    String? source,
  }) = _MissionSchedule;

  /// silent_guardian / coach: the "mission" puts the robot in a mode.
  bool get isModeMission =>
      missionType == 'silent_guardian' || missionType == 'coach';

  /// Scheduled by Claude / the voice agent through the relay.
  bool get isFromAssistant => source == 'relay_settings';

  /// Lenient parser for robot `schedules_list` / `schedule_created` rows.
  /// Relay-settings entries don't carry every legacy field (`mission_name`,
  /// `end_time`, long day names), and a single strict-cast failure used to
  /// throw inside the WS listener and drop the WHOLE list — the stale-cache
  /// bug in the 2026-11-07 brief. Returns null only when there is no id.
  static MissionSchedule? tryParse(Map<String, dynamic> j) {
    final id = (j['schedule_id'] ?? j['id'])?.toString();
    if (id == null || id.isEmpty) return null;
    final missionType = j['mission_type']?.toString();
    final name = j['name']?.toString() ?? '';
    final missionName =
        (j['mission_name'] ?? missionType ?? (name.isNotEmpty ? name : null))
                ?.toString() ??
            'mission';
    final start = _hhmm(j['start_time'] ?? j['time']) ?? '00:00';
    final end = _hhmm(j['end_time']) ?? _plusHours(start, 4);
    final days = _dayNames(j['days_of_week'] ?? j['days']);
    final rawType = j['type']?.toString();
    final type = switch (rawType) {
      'once' => ScheduleType.once,
      'weekly' => ScheduleType.weekly,
      'daily' => ScheduleType.daily,
      _ => (days.isNotEmpty && days.length < 7)
          ? ScheduleType.weekly
          : ScheduleType.daily,
    };
    return MissionSchedule(
      id: id,
      missionName: missionName,
      dogId: j['dog_id']?.toString() ?? '',
      name: name,
      type: type,
      startTime: start,
      endTime: end,
      daysOfWeek: days,
      enabled: j['enabled'] is bool ? j['enabled'] as bool : true,
      cooldownHours: (j['cooldown_hours'] as num?)?.toInt() ?? 24,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
      missionType: missionType,
      source: j['source']?.toString(),
    );
  }

  static String? _hhmm(dynamic v) {
    if (v == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v.toString());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return timeFromHourMinute(h, min);
  }

  static String _plusHours(String hhmm, int hours) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    return timeFromHourMinute((h + hours) % 24, int.tryParse(parts[1]) ?? 0);
  }

  /// Accepts long ("monday"), short ("mon") or int (0=Sun) day forms.
  static List<String> _dayNames(dynamic v) {
    if (v is! List) return const [];
    const short = {
      'sun': DayOfWeek.sunday, 'mon': DayOfWeek.monday, 'tue': DayOfWeek.tuesday,
      'wed': DayOfWeek.wednesday, 'thu': DayOfWeek.thursday,
      'fri': DayOfWeek.friday, 'sat': DayOfWeek.saturday,
    };
    final out = <String>[];
    for (final d in v) {
      String? name;
      if (d is int) {
        name = DayOfWeek.fromInt(d);
      } else {
        final s = d.toString().toLowerCase();
        name = DayOfWeek.all.contains(s)
            ? s
            : short[s.length >= 3 ? s.substring(0, 3) : s];
      }
      if (name != null && !out.contains(name)) out.add(name);
    }
    return out;
  }

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
