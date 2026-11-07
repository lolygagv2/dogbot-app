import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/schedule.dart';
import '../../l10n/l10n.dart';
import 'l10n_provider.dart';

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

  AppLocalizations get _l => _ref.read(l10nProvider);
  SharedPreferences? _prefs;
  StreamSubscription? _wsSubscription;

  // Track pending operations for timeout handling
  final Map<String, Completer<bool>> _pendingOperations = {};
  // Ids with a delete_schedule already sent and not yet answered.
  final Set<String> _deletesInFlight = {};
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
    // Relay brief 2026-11-07 §3: the robot's list is the truth — redraw from
    // it, never merge. Parse leniently so one odd row can't drop the list.
    final schedules = <MissionSchedule>[];
    for (final raw in schedulesJson) {
      if (raw is! Map) continue;
      final parsed = MissionSchedule.tryParse(raw.cast<String, dynamic>());
      if (parsed == null) {
        connTrace('schedule-parse-skip', '${raw.keys}');
        continue;
      }
      schedules.add(parsed);
    }

    // Note: refresh() already cleared the error when it was issued; don't
    // clear again here or a delete failure reported meanwhile would vanish.
    state = state.copyWith(
      schedules: schedules,
      isLoading: false,
    );
    connTrace('schedules-list',
        '${schedules.length} rows (relay_settings=${schedules.where((s) => s.isFromAssistant).length})');
  }

  void _handleScheduleCreated(Map<String, dynamic> data) {
    // Build 41: Accept multiple field names for schedule_id
    final scheduleId = data['schedule_id'] as String? ??
                       data['id'] as String?;
    // Build 41.1: Check success field - robot may return success: false
    final success = data['success'] as bool? ?? true;
    print('Scheduler: schedule_created event, id=$scheduleId, success=$success, data keys: ${data.keys}');

    // Build 41.1: If success is false, complete pending operation as failed and remove ghost entry
    if (!success) {
      final error = data['error'] as String? ?? _l.scheduleEditCreateFailed;
      print('Scheduler: Create failed - $error');

      if (scheduleId != null && _pendingOperations.containsKey(scheduleId)) {
        _completePendingOperation(scheduleId, false);
        // Remove optimistically added schedule
        state = state.copyWith(
          schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
          error: error,
        );
      } else if (_pendingOperations.isNotEmpty) {
        // Fallback: complete the first pending operation as failed
        final firstPendingId = _pendingOperations.keys.first;
        _completePendingOperation(firstPendingId, false);
        state = state.copyWith(
          schedules: state.schedules.where((s) => s.id != firstPendingId).toList(),
          error: error,
        );
      }
      return;
    }

    // Success case - complete pending operation
    if (scheduleId != null && _pendingOperations.containsKey(scheduleId)) {
      _completePendingOperation(scheduleId, true);
    } else if (_pendingOperations.isNotEmpty) {
      // Fallback: complete the first pending operation
      final firstPendingId = _pendingOperations.keys.first;
      print('Scheduler: No exact ID match, completing pending operation $firstPendingId');
      _completePendingOperation(firstPendingId, true);
    }

    // Update state with schedule data (nested `schedule` map, or flat)
    final raw = data['schedule'] is Map
        ? (data['schedule'] as Map).cast<String, dynamic>()
        : data;
    final schedule = MissionSchedule.tryParse(raw);
    if (schedule != null) {
      _addOrUpdateSchedule(schedule);
    } else {
      connTrace('schedule-created-unparsed', '${data.keys}');
    }
  }

  void _addOrUpdateSchedule(MissionSchedule schedule) {
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

  void _handleScheduleUpdated(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    print('Scheduler: schedule_updated event, id=$scheduleId');

    _completePendingOperation(scheduleId, true);

    if (data['schedule'] is Map) {
      final schedule =
          MissionSchedule.tryParse((data['schedule'] as Map).cast<String, dynamic>());
      if (schedule != null) {
        state = state.copyWith(
          schedules: state.schedules.map((s) => s.id == schedule.id ? schedule : s).toList(),
        );
      }
    }
  }

  void _handleScheduleDeleted(Map<String, dynamic> data) {
    final scheduleId = (data['schedule_id'] ?? data['id'])?.toString();
    final success = data['success'] is bool ? data['success'] as bool : true;
    final error = data['error']?.toString() ?? '';
    // Relay brief 2026-11-07 §2: success:false + "not found" means the robot
    // already dropped it — that IS a successful delete from the user's view.
    final alreadyGone =
        !success && error.toLowerCase().contains('not found');
    final ok = success || alreadyGone;
    connTrace('schedule-deleted',
        'id=$scheduleId success=$success alreadyGone=$alreadyGone err=$error');

    _completePendingOperation(scheduleId, ok);

    if (scheduleId != null && ok) {
      state = state.copyWith(
        schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
        clearError: true,
      );
    }
    // §3: after ANY schedule_deleted, redraw from the robot's list so the
    // app never keeps an entry the robot no longer has.
    refresh();
    if (!ok) {
      state = state.copyWith(
          error: error.isNotEmpty ? error : _l.schedErrDeleteFailed);
    }
  }

  void _handleScheduleError(Map<String, dynamic> data) {
    final scheduleId = data['schedule_id'] as String?;
    final error = data['error'] as String? ?? _l.unknownError;
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

  /// Refresh schedules from robot (coalesced: one get_schedules while a
  /// reply is outstanding).
  Future<void> refresh() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final ws = _ref.read(websocketClientProvider);
    connTrace('schedules-refresh', 'get_schedules');
    ws.sendGetSchedules();

    // Timeout after 10 seconds
    Future.delayed(_operationTimeout, () {
      if (state.isLoading) {
        state = state.copyWith(
          isLoading: false,
          error: _l.schedErrTimeout,
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
          error: state.error ?? _l.scheduleEditCreateFailed,
        );
      }

      return success;
    } catch (e) {
      print('Scheduler: Create error: $e');
      state = state.copyWith(
        schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
        error: _l.scheduleEditCreateFailed,
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
          error: state.error ?? _l.scheduleEditUpdateFailed,
        );
      }

      return success;
    } catch (e) {
      print('Scheduler: Update error: $e');
      state = state.copyWith(
        schedules: state.schedules.map((s) => s.id == schedule.id ? oldSchedule : s).toList(),
        error: _l.scheduleEditUpdateFailed,
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

  /// Delete a schedule.
  /// Relay brief 2026-11-07: exactly ONE delete_schedule per tap (a second
  /// call for the same id while one is in flight is a no-op), and on
  /// failure / timeout the entry is NOT re-added optimistically — the list
  /// is redrawn from the robot's `schedules_list` instead (§3).
  Future<bool> deleteSchedule(String scheduleId) async {
    if (_deletesInFlight.contains(scheduleId)) {
      connTrace('schedule-delete-dup', 'id=$scheduleId ignored (in flight)');
      return false;
    }
    if (!state.schedules.any((s) => s.id == scheduleId)) {
      connTrace('schedule-delete-skip', 'id=$scheduleId not in list');
      return true;
    }
    _deletesInFlight.add(scheduleId);

    // Optimistic update
    state = state.copyWith(
      schedules: state.schedules.where((s) => s.id != scheduleId).toList(),
      clearError: true,
    );

    final completer = Completer<bool>();
    _pendingOperations[scheduleId] = completer;

    // Send WebSocket command to robot (once)
    final ws = _ref.read(websocketClientProvider);
    connTrace('schedule-delete-send', 'id=$scheduleId');
    ws.sendDeleteSchedule(scheduleId);

    try {
      final success = await completer.future.timeout(
        _operationTimeout,
        onTimeout: () {
          connTrace('schedule-delete-timeout', 'id=$scheduleId');
          _pendingOperations.remove(scheduleId);
          return false;
        },
      );
      if (!success) {
        refresh(); // robot's list decides what comes back
        if (state.error == null) {
          state = state.copyWith(error: _l.schedErrDeleteFailed);
        }
      }
      return success;
    } catch (e) {
      connTrace('schedule-delete-error', 'id=$scheduleId $e');
      refresh();
      state = state.copyWith(error: _l.schedErrDeleteFailed);
      return false;
    } finally {
      _deletesInFlight.remove(scheduleId);
    }
  }

  /// Clear state (used on logout)
  void clearState() {
    _pendingOperations.clear();
    _deletesInFlight.clear();
    state = const SchedulerState();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _pendingOperations.clear();
    super.dispose();
  }
}
