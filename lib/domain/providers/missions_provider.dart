import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/mission.dart';

/// Predefined training missions
final _predefinedMissions = [
  const Mission(
    id: 'sit_training',
    name: 'Sit Training',
    description: 'Teach your dog to sit on command and hold the position',
    targetBehavior: 'sit',
    requiredDuration: 3.0,
    cooldownSeconds: 15,
    dailyLimit: 10,
  ),
  const Mission(
    id: 'down_training',
    name: 'Down Training',
    description: 'Train your dog to lie down and stay in position',
    targetBehavior: 'down',
    requiredDuration: 3.0,
    cooldownSeconds: 15,
    dailyLimit: 10,
  ),
  const Mission(
    id: 'stay_training',
    name: 'Stay Training',
    description: 'Build duration — reward your dog for holding still',
    targetBehavior: 'stay',
    requiredDuration: 5.0,
    cooldownSeconds: 20,
    dailyLimit: 8,
  ),
  const Mission(
    id: 'quiet_training',
    name: 'Quiet Training',
    description: 'Reward calm, quiet behavior and reduce excessive barking',
    targetBehavior: 'quiet',
    requiredDuration: 10.0,
    cooldownSeconds: 30,
    dailyLimit: 6,
  ),
  const Mission(
    id: 'stand_training',
    name: 'Stand Training',
    description: 'Teach your dog to stand on all fours from sit or down',
    targetBehavior: 'stand',
    requiredDuration: 3.0,
    cooldownSeconds: 15,
    dailyLimit: 10,
  ),
];

/// Missions state
class MissionsState {
  final List<Mission> missions;
  final String? activeMissionId;
  final double activeProgress;
  final int activeRewards;
  final String? error;

  const MissionsState({
    this.missions = const [],
    this.activeMissionId,
    this.activeProgress = 0.0,
    this.activeRewards = 0,
    this.error,
  });

  MissionsState copyWith({
    List<Mission>? missions,
    String? activeMissionId,
    double? activeProgress,
    int? activeRewards,
    String? error,
    bool clearActiveMission = false,
    bool clearError = false,
  }) {
    return MissionsState(
      missions: missions ?? this.missions,
      activeMissionId: clearActiveMission ? null : (activeMissionId ?? this.activeMissionId),
      activeProgress: activeProgress ?? this.activeProgress,
      activeRewards: activeRewards ?? this.activeRewards,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasActiveMission => activeMissionId != null;

  Mission? get activeMission {
    if (activeMissionId == null) return null;
    try {
      return missions.firstWhere((m) => m.id == activeMissionId);
    } catch (_) {
      return null;
    }
  }
}

/// Provider for missions state
final missionsProvider =
    StateNotifierProvider<MissionsNotifier, MissionsState>((ref) {
  return MissionsNotifier(ref);
});

/// Convenience provider for the active mission
final activeMissionProvider = Provider<Mission?>((ref) {
  return ref.watch(missionsProvider).activeMission;
});

/// Convenience provider for a specific mission by ID
final missionByIdProvider = Provider.family<Mission?, String>((ref, id) {
  final missions = ref.watch(missionsProvider).missions;
  try {
    return missions.firstWhere((m) => m.id == id);
  } catch (_) {
    return null;
  }
});

/// Missions state notifier
class MissionsNotifier extends StateNotifier<MissionsState> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  MissionsNotifier(this._ref) : super(MissionsState(missions: _predefinedMissions)) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'mission_progress':
        final progress = MissionProgress.fromWsEvent(event.data);
        if (progress.missionId == state.activeMissionId) {
          // Update active mission progress
          state = state.copyWith(
            activeProgress: progress.progress,
            activeRewards: progress.rewardsGiven,
          );
          // Update mission's rewardsGiven in the list
          _updateMissionInList(progress.missionId, rewardsGiven: progress.rewardsGiven);
        }
        break;

      case 'mission_complete':
        final missionId = event.data['mission_id'] as String? ?? event.data['id'] as String? ?? '';
        if (missionId == state.activeMissionId) {
          state = state.copyWith(
            activeProgress: 1.0,
            clearActiveMission: true,
          );
          _updateMissionInList(missionId, isActive: false);
        }
        break;

      case 'mission_stopped':
        final missionId = event.data['mission_id'] as String? ?? event.data['id'] as String? ?? '';
        if (missionId == state.activeMissionId) {
          state = state.copyWith(
            clearActiveMission: true,
            activeProgress: 0.0,
            activeRewards: 0,
          );
          _updateMissionInList(missionId, isActive: false);
        }
        break;
    }
  }

  void _updateMissionInList(String missionId, {int? rewardsGiven, bool? isActive}) {
    final updatedMissions = state.missions.map((m) {
      if (m.id == missionId) {
        return Mission(
          id: m.id,
          name: m.name,
          description: m.description,
          targetBehavior: m.targetBehavior,
          requiredDuration: m.requiredDuration,
          cooldownSeconds: m.cooldownSeconds,
          dailyLimit: m.dailyLimit,
          isActive: isActive ?? m.isActive,
          rewardsGiven: rewardsGiven ?? m.rewardsGiven,
          progress: m.progress,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(missions: updatedMissions);
  }

  /// Start a mission
  void startMission(String missionId) {
    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('start_mission', {'mission_id': missionId});

    // Optimistic update
    state = state.copyWith(
      activeMissionId: missionId,
      activeProgress: 0.0,
      activeRewards: 0,
      clearError: true,
    );
    _updateMissionInList(missionId, isActive: true);
  }

  /// Stop the active mission
  void stopMission() {
    if (state.activeMissionId == null) return;

    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('stop_mission', {'mission_id': state.activeMissionId});

    final stoppedId = state.activeMissionId!;
    state = state.copyWith(
      clearActiveMission: true,
      activeProgress: 0.0,
      activeRewards: 0,
    );
    _updateMissionInList(stoppedId, isActive: false);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
