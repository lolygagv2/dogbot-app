import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/robot_api.dart';
import '../../data/models/mission.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';

/// History filter settings
class HistoryFilter {
  final String? dogId;
  final int days;
  final String? missionId;

  const HistoryFilter({
    this.dogId,
    this.days = 7,
    this.missionId,
  });

  HistoryFilter copyWith({
    String? dogId,
    int? days,
    String? missionId,
    bool clearDogId = false,
    bool clearMissionId = false,
  }) {
    return HistoryFilter(
      dogId: clearDogId ? null : (dogId ?? this.dogId),
      days: days ?? this.days,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
    );
  }
}

/// History state
class HistoryState {
  final List<MissionHistoryEntry> entries;
  final MissionStats? stats;
  final bool isLoading;
  final String? error;
  final HistoryFilter filter;

  const HistoryState({
    this.entries = const [],
    this.stats,
    this.isLoading = false,
    this.error,
    this.filter = const HistoryFilter(),
  });

  HistoryState copyWith({
    List<MissionHistoryEntry>? entries,
    MissionStats? stats,
    bool? isLoading,
    String? error,
    HistoryFilter? filter,
    bool clearError = false,
    bool clearStats = false,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      stats: clearStats ? null : (stats ?? this.stats),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }

  /// Total treats given across all entries
  int get totalTreats => entries.fold(0, (sum, e) => sum + e.treatsGiven);

  /// Total missions completed
  int get completedMissions => entries.where((e) => e.wasCompleted).length;

  /// Success rate
  double get successRate {
    if (entries.isEmpty) return 0.0;
    return completedMissions / entries.length;
  }

  /// Group entries by date
  Map<DateTime, List<MissionHistoryEntry>> get entriesByDate {
    final map = <DateTime, List<MissionHistoryEntry>>{};
    for (final entry in entries) {
      final date = DateTime(
        entry.startedAt.year,
        entry.startedAt.month,
        entry.startedAt.day,
      );
      map.putIfAbsent(date, () => []).add(entry);
    }
    return map;
  }

  /// Group entries by mission
  Map<String, List<MissionHistoryEntry>> get entriesByMission {
    final map = <String, List<MissionHistoryEntry>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.missionName, () => []).add(entry);
    }
    return map;
  }
}

/// Provider for history filter
final historyFilterProvider = StateProvider<HistoryFilter>((ref) {
  // Default to selected dog if any
  final selectedDog = ref.watch(selectedDogProvider);
  return HistoryFilter(dogId: selectedDog?.id);
});

/// Provider for history state
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});

/// History state notifier
class HistoryNotifier extends StateNotifier<HistoryState> {
  final Ref _ref;

  HistoryNotifier(this._ref) : super(const HistoryState());

  /// Load history with current filter
  Future<void> loadHistory() async {
    final token = _ref.read(authTokenProvider);
    if (token == null) {
      state = state.copyWith(error: 'Not logged in');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final api = _ref.read(robotApiProvider);
      final filter = state.filter;

      // Fetch history
      final entries = await api.getMissionHistory(
        token: token,
        dogId: filter.dogId,
        days: filter.days,
      );

      // Fetch stats if we have a specific dog
      MissionStats? stats;
      if (filter.dogId != null) {
        stats = await api.getMissionStats(
          token: token,
          dogId: filter.dogId!,
        );
      }

      state = state.copyWith(
        entries: entries,
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load history: $e',
      );
    }
  }

  /// Update filter and reload
  Future<void> setFilter(HistoryFilter filter) async {
    state = state.copyWith(filter: filter);
    await loadHistory();
  }

  /// Set days filter
  Future<void> setDays(int days) async {
    await setFilter(state.filter.copyWith(days: days));
  }

  /// Set dog filter
  Future<void> setDogId(String? dogId) async {
    if (dogId == null) {
      await setFilter(state.filter.copyWith(clearDogId: true));
    } else {
      await setFilter(state.filter.copyWith(dogId: dogId));
    }
  }

  /// Clear filter
  Future<void> clearFilter() async {
    await setFilter(const HistoryFilter());
  }

  /// Refresh history
  Future<void> refresh() async {
    await loadHistory();
  }

  /// Clear state
  void clearState() {
    state = const HistoryState();
  }
}

/// Provider for history entries grouped by date
final historyByDateProvider = Provider<Map<DateTime, List<MissionHistoryEntry>>>((ref) {
  return ref.watch(historyProvider).entriesByDate;
});

/// Provider for history entries grouped by mission
final historyByMissionProvider = Provider<Map<String, List<MissionHistoryEntry>>>((ref) {
  return ref.watch(historyProvider).entriesByMission;
});
