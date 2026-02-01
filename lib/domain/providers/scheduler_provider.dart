import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/schedule.dart';

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
/// Build 38: Uses WebSocket commands to robot instead of REST API
/// Robot stores schedules locally for offline execution
class SchedulerNotifier extends StateNotifier<SchedulerState> {
  final Ref _ref;
  SharedPreferences? _prefs;
  StreamSubscription? _wsSubscription;

  // Track pending operations for timeout handling
  final Map<String, Completer<bool>> _pendingOperations = {};
  static const _operationTimeout = Duration(seconds: 10);

  SchedulerNotifier(this._ref) : super(const SchedulerState()) {
    _init();
  }

  Future<void> _init() async {
    // Load cached enabled state
    _prefs ??= await SharedPreferences.getInstance();
    final cachedEnabled = _prefs?.getBool(_schedulerEnabledKey) ?? true;
    state = state.copyWith(isGlobalEnabled: cachedEnabled);

    // Listen for schedule events from robot
    _listenToWebSocket();

    // Request initial schedules from robot
    refresh();
  }

  void _listenToWebSocket() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'schedules_list':
        // Response to get_schedules command
        _handleSchedulesList(event.data);
        break;
      case 'schedule_created':
        _handleScheduleCreated(event.data);
        break;
      case 'schedule_updated':
        _handleScheduleUpdated(event.data);
        break;
      case 'schedule_deleted':
        _handleScheduleDeleted(event.data);
        break;
      case 'schedule_error':
        _handleScheduleError(event.data);
        break;
      case 'scheduling_enabled':
        _handleSchedulingEnabled(event.data);
        break;
    }
  }

  void _handleSchedulesList(Map<String, dynamic> data) {
    print('Scheduler: Received schedules_list');
    final schedulesJson = data['schedules'] as List? ?? [];
    final schedules = schedulesJson
        .map((s) => MissionSchedule.fromJson(s as Map<String, dynamic>))
        .toList();

    state = state.copyWith(
      schedules: schedules,
      isLoading: false,
      clearError: true,
    );
    print('Scheduler: Loaded ${schedules.length} schedules from robot');
  }

  void _handleScheduleCreated(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    print('Scheduler: schedule_created event, id=$scheduleId');

    // Complete pending operation if exists
    _completePendingOperation(scheduleId, true);

    // If we have the full schedule data, update state
    if (data.containsKey('schedule')) {
      final schedule = MissionSchedule.fromJson(data['schedule'] as Map<String, dynamic>);
      // Update or add the schedule
      final existing = state.schedules.any((s) => s.id == schedule.id);
      if (existing) {
        state = state.copyWith(
          schedules: state.schedules.map((s) => s.id == schedule.id ? schedule : s).toList(),
        );
      } else {
        state = state.copyWith(
          schedules: [...state.schedules, schedule],
        );
      }
    }
  }

  void _handleScheduleUpdated(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    print('Scheduler: schedule_updated event, id=$scheduleId');

    _completePendingOperation(scheduleId, true);

    if (data.containsKey('schedule')) {
      final schedule = MissionSchedule.fromJson(data['schedule'] as Map<String, dynamic>);
      state = state.copyWith(
        schedules: state.schedules.map((s) => s.id == schedule.id ? schedule : s).toList(),
      );
    }
  }

  void _handleScheduleDeleted(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    print('Scheduler: schedule_deleted event, id=$scheduleId');

    _completePendingOperation(scheduleId, true);

    if (scheduleId != null) {
      state = state.copyWith(
        schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
      );
    }
  }

  void _handleScheduleError(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    final error = data['error'] as String? ?? 'Unknown error';
    print('Scheduler: schedule_error event, id=$scheduleId, error=$error');

    _completePendingOperation(scheduleId, false);

    state = state.copyWith(error: error);
  }

  void _handleSchedulingEnabled(Map<String, dynamic> data) {
    final enabled = data['enabled'] as bool? ?? true;
    print('Scheduler: scheduling_enabled event, enabled=$enabled');

    state = state.copyWith(isGlobalEnabled: enabled);
    _prefs?.setBool(_schedulerEnabledKey, enabled);
  }

  void _completePendingOperation(String? id, bool success) {
    if (id != null && _pendingOperations.containsKey(id)) {
      _pendingOperations[id]?.complete(success);
      _pendingOperations.remove(id);
    }
  }

  /// Refresh schedules from robot
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final ws = _ref.read(websocketClientProvider);
    ws.sendGetSchedules();

    // Timeout after 10 seconds
    Future.delayed(_operationTimeout, () {
      if (state.isLoading) {
        state = state.copyWith(
          isLoading: false,
          error: 'Timeout waiting for schedules from robot',
        );
      }
    });
  }

  /// Toggle global scheduling on/off
  Future<void> toggleGlobalEnabled() async {
    final newEnabled = !state.isGlobalEnabled;

    // Optimistic update
    state = state.copyWith(isGlobalEnabled: newEnabled);
    await _prefs?.setBool(_schedulerEnabledKey, newEnabled);

    // Send to robot via WebSocket
    final ws = _ref.read(websocketClientProvider);
    ws.sendSetSchedulingEnabled(newEnabled);

    print('Scheduler: Sent set_scheduling_enabled=$newEnabled');
  }

  /// Create a new schedule
  /// Build 38: Sends WebSocket command to robot
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
    final scheduleId = const Uuid().v4();
    final startTime = MissionSchedule.timeFromHourMinute(hour, minute);
    final endHour = (hour + 4) % 24;
    final endTime = MissionSchedule.timeFromHourMinute(endHour, minute);
    final daysOfWeek = MissionSchedule.weekdaysToNames(weekdays);
    final typeStr = type.name; // 'once', 'daily', 'weekly'

    // Create local schedule for optimistic update
    final schedule = MissionSchedule(
      id: scheduleId,
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

    // Send WebSocket command to robot
    final ws = _ref.read(websocketClientProvider);
    ws.sendCreateSchedule(
      scheduleId: scheduleId,
      missionName: missionName,
      dogId: dogId,
      type: typeStr,
      startTime: startTime,
      daysOfWeek: daysOfWeek,
      enabled: true,
      cooldownHours: cooldownHours,
    );

    // Wait for response with timeout
    final completer = Completer<bool>();
    _pendingOperations[scheduleId] = completer;

    try {
      final success = await completer.future.timeout(
        _operationTimeout,
        onTimeout: () {
          print('Scheduler: Create timeout for $scheduleId');
          _pendingOperations.remove(scheduleId);
          return false;
        },
      );

      if (!success) {
        // Revert optimistic update
        state = state.copyWith(
          schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
          error: state.error ?? 'Failed to create schedule',
        );
      }

      return success;
    } catch (e) {
      print('Scheduler: Create error: $e');
      state = state.copyWith(
        schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
        error: 'Failed to create schedule',
      );
      return false;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(MissionSchedule schedule) async {
    final oldSchedule = state.schedules.firstWhere(
      (s) => s.id == schedule.id,
      orElse: () => schedule,
    );

    // Optimistic update
    state = state.copyWith(
      schedules: state.schedules.map((s) => s.id == schedule.id ? schedule : s).toList(),
      clearError: true,
    );

    // Send WebSocket command to robot
    final ws = _ref.read(websocketClientProvider);
    ws.sendUpdateSchedule(
      scheduleId: schedule.id,
      missionName: schedule.missionName,
      dogId: schedule.dogId,
      type: schedule.type.name,
      startTime: schedule.startTime,
      daysOfWeek: schedule.daysOfWeek,
      enabled: schedule.enabled,
      cooldownHours: schedule.cooldownHours,
    );

    // Wait for response with timeout
    final completer = Completer<bool>();
    _pendingOperations[schedule.id] = completer;

    try {
      final success = await completer.future.timeout(
        _operationTimeout,
        onTimeout: () {
          print('Scheduler: Update timeout for ${schedule.id}');
          _pendingOperations.remove(schedule.id);
          return false;
        },
      );

      if (!success) {
        // Revert
        state = state.copyWith(
          schedules: state.schedules.map((s) => s.id == schedule.id ? oldSchedule : s).toList(),
          error: state.error ?? 'Failed to update schedule',
        );
      }

      return success;
    } catch (e) {
      print('Scheduler: Update error: $e');
      state = state.copyWith(
        schedules: state.schedules.map((s) => s.id == schedule.id ? oldSchedule : s).toList(),
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
    final oldSchedule = state.schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => throw Exception('Schedule not found'),
    );

    // Optimistic update
    state = state.copyWith(
      schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
      clearError: true,
    );

    // Send WebSocket command to robot
    final ws = _ref.read(websocketClientProvider);
    ws.sendDeleteSchedule(scheduleId);

    // Wait for response with timeout
    final completer = Completer<bool>();
    _pendingOperations[scheduleId] = completer;

    try {
      final success = await completer.future.timeout(
        _operationTimeout,
        onTimeout: () {
          print('Scheduler: Delete timeout for $scheduleId');
          _pendingOperations.remove(scheduleId);
          return false;
        },
      );

      if (!success) {
        // Revert
        state = state.copyWith(
          schedules: [...state.schedules, oldSchedule],
          error: state.error ?? 'Failed to delete schedule',
        );
      }

      return success;
    } catch (e) {
      print('Scheduler: Delete error: $e');
      state = state.copyWith(
        schedules: [...state.schedules, oldSchedule],
        error: 'Failed to delete schedule',
      );
      return false;
    }
  }

  /// Clear state (used on logout)
  void clearState() {
    _pendingOperations.clear();
    state = const SchedulerState();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _pendingOperations.clear();
    super.dispose();
  }
}
