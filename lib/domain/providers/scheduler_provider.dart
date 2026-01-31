import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/robot_api.dart';
import '../../data/models/schedule.dart';
import 'auth_provider.dart';

/// Cache key for scheduler enabled state
const _schedulerEnabledKey = 'scheduler_global_enabled';

/// Provider for scheduler state
final schedulerProvider =
    StateNotifierProvider<SchedulerNotifier, SchedulerState>((ref) {
  return SchedulerNotifier(ref);
});

/// Convenience provider for sorted schedules list
final sortedSchedulesProvider = Provider<List<MissionSchedule>>((ref) {
  return ref.watch(schedulerProvider).sortedSchedules;
});

/// Provider for a specific schedule by ID
final scheduleByIdProvider = Provider.family<MissionSchedule?, String>((ref, id) {
  final schedules = ref.watch(schedulerProvider).schedules;
  try {
    return schedules.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

/// Scheduler state notifier
class SchedulerNotifier extends StateNotifier<SchedulerState> {
  final Ref _ref;
  SharedPreferences? _prefs;
  bool _isLoading = false;

  SchedulerNotifier(this._ref) : super(const SchedulerState()) {
    _loadSchedules();
  }

  /// Load schedules from server
  Future<void> _loadSchedules() async {
    if (_isLoading) return;
    _isLoading = true;

    state = state.copyWith(isLoading: true, clearError: true);

    // Load cached enabled state
    _prefs ??= await SharedPreferences.getInstance();
    final cachedEnabled = _prefs?.getBool(_schedulerEnabledKey) ?? true;
    state = state.copyWith(isGlobalEnabled: cachedEnabled);

    final token = _ref.read(authTokenProvider);
    if (token == null) {
      state = state.copyWith(isLoading: false);
      _isLoading = false;
      return;
    }

    try {
      final api = _ref.read(robotApiProvider);
      final schedules = await api.getSchedules(token);
      state = state.copyWith(
        schedules: schedules,
        isLoading: false,
      );
      print('Scheduler: Loaded ${schedules.length} schedules');
    } catch (e) {
      print('Scheduler: Failed to load schedules: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load schedules',
      );
    }

    _isLoading = false;
  }

  /// Refresh schedules from server
  Future<void> refresh() async {
    await _loadSchedules();
  }

  /// Toggle global scheduling on/off
  Future<void> toggleGlobalEnabled() async {
    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    final newEnabled = !state.isGlobalEnabled;
    state = state.copyWith(isGlobalEnabled: newEnabled);

    // Persist locally
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_schedulerEnabledKey, newEnabled);

    // Send to server
    try {
      final api = _ref.read(robotApiProvider);
      if (newEnabled) {
        await api.enableScheduling(token);
      } else {
        await api.disableScheduling(token);
      }
      print('Scheduler: Global enabled = $newEnabled');
    } catch (e) {
      print('Scheduler: Failed to toggle global enabled: $e');
      // Revert on failure
      state = state.copyWith(isGlobalEnabled: !newEnabled);
      await _prefs?.setBool(_schedulerEnabledKey, !newEnabled);
    }
  }

  /// Create a new schedule (Build 34: Updated for Robot API format)
  Future<bool> createSchedule({
    required String missionName,
    required String dogId,
    String name = '',
    required ScheduleType type,
    required int hour,
    required int minute,
    List<int> weekdays = const [],
    int cooldownHours = 24,
  }) async {
    final token = _ref.read(authTokenProvider);
    if (token == null) return false;

    // Convert hour/minute to time strings and weekdays to day names
    final startTime = MissionSchedule.timeFromHourMinute(hour, minute);
    // Default end time is 4 hours after start
    final endHour = (hour + 4) % 24;
    final endTime = MissionSchedule.timeFromHourMinute(endHour, minute);
    final daysOfWeek = MissionSchedule.weekdaysToNames(weekdays);

    final schedule = MissionSchedule(
      id: const Uuid().v4(),
      missionName: missionName,
      dogId: dogId,
      name: name,
      type: type,
      startTime: startTime,
      endTime: endTime,
      daysOfWeek: daysOfWeek,
      enabled: true,
      cooldownHours: cooldownHours,
    );

    // Optimistic update
    state = state.copyWith(
      schedules: [...state.schedules, schedule],
      clearError: true,
    );

    try {
      final api = _ref.read(robotApiProvider);
      final created = await api.createSchedule(token, schedule);
      if (created != null) {
        // Update with server response (may include nextRun)
        state = state.copyWith(
          schedules: state.schedules.map((s) {
            return s.id == schedule.id ? created : s;
          }).toList(),
        );
        print('Scheduler: Created schedule ${created.id}');
        return true;
      } else {
        // Revert
        state = state.copyWith(
          schedules: state.schedules.where((s) => s.id != schedule.id).toList(),
          error: 'Failed to create schedule',
        );
        return false;
      }
    } catch (e) {
      print('Scheduler: Failed to create schedule: $e');
      state = state.copyWith(
        schedules: state.schedules.where((s) => s.id != schedule.id).toList(),
        error: 'Failed to create schedule',
      );
      return false;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(MissionSchedule schedule) async {
    final token = _ref.read(authTokenProvider);
    if (token == null) return false;

    final oldSchedule = state.schedules.firstWhere(
      (s) => s.id == schedule.id,
      orElse: () => schedule,
    );

    // Optimistic update
    state = state.copyWith(
      schedules: state.schedules.map((s) {
        return s.id == schedule.id ? schedule : s;
      }).toList(),
      clearError: true,
    );

    try {
      final api = _ref.read(robotApiProvider);
      final updated = await api.updateSchedule(token, schedule);
      if (updated != null) {
        state = state.copyWith(
          schedules: state.schedules.map((s) {
            return s.id == schedule.id ? updated : s;
          }).toList(),
        );
        print('Scheduler: Updated schedule ${schedule.id}');
        return true;
      } else {
        // Revert
        state = state.copyWith(
          schedules: state.schedules.map((s) {
            return s.id == schedule.id ? oldSchedule : s;
          }).toList(),
          error: 'Failed to update schedule',
        );
        return false;
      }
    } catch (e) {
      print('Scheduler: Failed to update schedule: $e');
      state = state.copyWith(
        schedules: state.schedules.map((s) {
          return s.id == schedule.id ? oldSchedule : s;
        }).toList(),
        error: 'Failed to update schedule',
      );
      return false;
    }
  }

  /// Toggle a schedule's enabled state
  Future<bool> toggleScheduleEnabled(String scheduleId) async {
    final schedule = state.schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => throw Exception('Schedule not found'),
    );

    return updateSchedule(schedule.copyWith(enabled: !schedule.enabled));
  }

  /// Delete a schedule
  Future<bool> deleteSchedule(String scheduleId) async {
    final token = _ref.read(authTokenProvider);
    if (token == null) return false;

    final oldSchedule = state.schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => throw Exception('Schedule not found'),
    );

    // Optimistic update
    state = state.copyWith(
      schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
      clearError: true,
    );

    try {
      final api = _ref.read(robotApiProvider);
      final success = await api.deleteSchedule(token, scheduleId);
      if (success) {
        print('Scheduler: Deleted schedule $scheduleId');
        return true;
      } else {
        // Revert
        state = state.copyWith(
          schedules: [...state.schedules, oldSchedule],
          error: 'Failed to delete schedule',
        );
        return false;
      }
    } catch (e) {
      print('Scheduler: Failed to delete schedule: $e');
      state = state.copyWith(
        schedules: [...state.schedules, oldSchedule],
        error: 'Failed to delete schedule',
      );
      return false;
    }
  }

  /// Clear state (used on logout)
  void clearState() {
    state = const SchedulerState();
  }
}
