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

/// Missions state (Build 31 - enhanced with full progress tracking)
class MissionsState {
  final List<Mission> missions;
  final String? activeMissionId;
  final double activeProgress;
  final int activeRewards;
  final String? error;
  // Build 31: Full progress state
  final MissionProgress? currentProgress;

  const MissionsState({
    this.missions = const [],
    this.activeMissionId,
    this.activeProgress = 0.0,
    this.activeRewards = 0,
    this.error,
    this.currentProgress,
  });

  MissionsState copyWith({
    List<Mission>? missions,
    String? activeMissionId,
    double? activeProgress,
    int? activeRewards,
    String? error,
    MissionProgress? currentProgress,
    bool clearActiveMission = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return MissionsState(
      missions: missions ?? this.missions,
      activeMissionId: clearActiveMission ? null : (activeMissionId ?? this.activeMissionId),
      activeProgress: clearActiveMission ? 0.0 : (activeProgress ?? this.activeProgress),
      activeRewards: clearActiveMission ? 0 : (activeRewards ?? this.activeRewards),
      error: clearError ? null : (error ?? this.error),
      currentProgress: clearProgress || clearActiveMission ? null : (currentProgress ?? this.currentProgress),
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

  /// Current mission status (Build 31)
  MissionStatus get activeStatus => currentProgress?.statusEnum ?? MissionStatus.unknown;

  /// Current trick being trained
  String? get activeTrick => currentProgress?.trick;

  /// Current stage (e.g., "Stage 2 of 5")
  String? get stageDisplay => currentProgress?.stageDisplay;

  /// Dog name being trained
  String? get activeDogName => currentProgress?.dogName;

  /// Target seconds for hold
  double? get targetSec => currentProgress?.targetSec;

  /// Human-readable status display
  String get statusDisplay => currentProgress?.statusDisplay ?? '';

  /// Whether to show progress indicator (during watching state)
  bool get showProgressIndicator => activeStatus == MissionStatus.watching;
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
        print('Missions: progress event - status=${progress.status}, mission=${progress.missionId}, stage=${progress.stageNumber}/${progress.totalStages}');

        // If we don't have an active mission but get progress, set it
        final missionId = progress.missionId.isNotEmpty
            ? progress.missionId
            : state.activeMissionId ?? '';

        if (missionId.isNotEmpty) {
          state = state.copyWith(
            activeMissionId: missionId,
            activeProgress: progress.effectiveProgress,
            activeRewards: progress.rewardsGiven,
            currentProgress: progress,
          );
          _updateMissionInList(missionId, rewardsGiven: progress.rewardsGiven, isActive: true);
        }
        break;

      case 'mission_complete':
        final missionId = event.data['mission_id'] as String? ?? event.data['id'] as String? ?? '';
        print('Missions: complete event - mission=$missionId');
        if (missionId == state.activeMissionId || state.activeMissionId == null) {
          final treatsGiven = event.data['treats_given'] as int? ?? event.data['rewards'] as int?;
          // Create final progress with completed status
          final finalProgress = MissionProgress(
            missionId: missionId,
            status: 'completed',
            rewardsGiven: treatsGiven ?? state.activeRewards,
            stageNumber: state.currentProgress?.totalStages,
            totalStages: state.currentProgress?.totalStages,
            dogName: state.currentProgress?.dogName,
          );
          state = state.copyWith(
            activeProgress: 1.0,
            activeRewards: treatsGiven ?? state.activeRewards,
            currentProgress: finalProgress,
          );
          _updateMissionInList(missionId, isActive: false, rewardsGiven: treatsGiven);

          // Clear after delay so user sees completion
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && state.activeStatus == MissionStatus.completed) {
              state = state.copyWith(clearActiveMission: true, clearProgress: true);
            }
          });
        }
        break;

      case 'mission_stopped':
        final missionId = event.data['mission_id'] as String? ?? event.data['id'] as String? ?? '';
        print('Missions: stopped event - mission=$missionId');
        if (missionId == state.activeMissionId || state.activeMissionId == null) {
          state = state.copyWith(
            clearActiveMission: true,
            clearProgress: true,
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

  /// Clear state (used on logout)
  void clearState() {
    state = MissionsState(missions: _predefinedMissions);
  }

  /// Start a mission
  void startMission(String missionId) {
    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('start_mission', {
      'mission_id': missionId,
      'mission_name': missionId,
    });

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
