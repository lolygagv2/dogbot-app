import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/program.dart';
import '../../data/models/mission.dart';
import 'missions_provider.dart';

/// Predefined training programs
final _predefinedPrograms = [
  const Program(
    id: 'puppy_basics',
    name: 'Puppy Basics',
    description: 'Foundation training: sit, down, and quiet behaviors',
    missionIds: ['sit_training', 'down_training', 'quiet_training'],
    restSecondsBetween: 60,
    iconName: 'pets',
  ),
  const Program(
    id: 'obedience_101',
    name: 'Obedience 101',
    description: 'Core commands every dog should know',
    missionIds: ['sit_training', 'down_training', 'stay_training', 'stand_training'],
    restSecondsBetween: 45,
    iconName: 'school',
  ),
  const Program(
    id: 'calm_dog',
    name: 'Calm Dog',
    description: 'Build patience and self-control',
    missionIds: ['stay_training', 'quiet_training'],
    restSecondsBetween: 90,
    iconName: 'self_improvement',
  ),
];

/// Programs state
class ProgramsState {
  final List<Program> programs;
  final String? activeProgramId;
  final ProgramProgress? currentProgress;
  final String? error;

  const ProgramsState({
    this.programs = const [],
    this.activeProgramId,
    this.currentProgress,
    this.error,
  });

  ProgramsState copyWith({
    List<Program>? programs,
    String? activeProgramId,
    ProgramProgress? currentProgress,
    String? error,
    bool clearActiveProgram = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return ProgramsState(
      programs: programs ?? this.programs,
      activeProgramId: clearActiveProgram ? null : (activeProgramId ?? this.activeProgramId),
      currentProgress: clearProgress || clearActiveProgram ? null : (currentProgress ?? this.currentProgress),
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasActiveProgram => activeProgramId != null;

  Program? get activeProgram {
    if (activeProgramId == null) return null;
    try {
      return programs.firstWhere((p) => p.id == activeProgramId);
    } catch (_) {
      return null;
    }
  }

  /// Get mission names for a program
  List<String> getMissionNames(Program program, List<Mission> missions) {
    return program.missionIds.map((id) {
      final mission = missions.cast<Mission?>().firstWhere(
        (m) => m?.id == id,
        orElse: () => null,
      );
      return mission?.name ?? id;
    }).toList();
  }
}

/// Provider for programs state
final programsProvider =
    StateNotifierProvider<ProgramsNotifier, ProgramsState>((ref) {
  return ProgramsNotifier(ref);
});

/// Convenience provider for a specific program by ID
final programByIdProvider = Provider.family<Program?, String>((ref, id) {
  final programs = ref.watch(programsProvider).programs;
  try {
    return programs.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});

/// Programs state notifier
class ProgramsNotifier extends StateNotifier<ProgramsState> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;
  Timer? _restTimer;

  ProgramsNotifier(this._ref) : super(ProgramsState(programs: _predefinedPrograms)) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'program_progress':
        final progress = ProgramProgress.fromWsEvent(event.data);
        print('Programs: progress event - mission=${progress.currentMissionIndex + 1}/${progress.totalMissions}, resting=${progress.isResting}');

        state = state.copyWith(
          activeProgramId: progress.programId,
          currentProgress: progress,
        );

        // Handle rest timer display
        if (progress.isResting && progress.restSecondsRemaining > 0) {
          _startRestCountdown(progress.restSecondsRemaining);
        }
        break;

      case 'program_complete':
        final programId = event.data['program_id'] as String? ?? '';
        print('Programs: complete event - program=$programId');

        if (programId == state.activeProgramId) {
          final finalProgress = ProgramProgress(
            programId: programId,
            currentMissionIndex: state.currentProgress?.totalMissions ?? 0,
            totalMissions: state.currentProgress?.totalMissions ?? 0,
            status: 'completed',
          );
          state = state.copyWith(currentProgress: finalProgress);

          // Clear after delay
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && state.currentProgress?.status == 'completed') {
              state = state.copyWith(clearActiveProgram: true, clearProgress: true);
            }
          });
        }
        break;

      case 'program_stopped':
        final programId = event.data['program_id'] as String? ?? '';
        print('Programs: stopped event - program=$programId');

        if (programId == state.activeProgramId) {
          _restTimer?.cancel();
          state = state.copyWith(clearActiveProgram: true, clearProgress: true);
        }
        break;
    }
  }

  void _startRestCountdown(int seconds) {
    _restTimer?.cancel();
    var remaining = seconds;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        return;
      }

      if (state.currentProgress != null && state.currentProgress!.isResting) {
        state = state.copyWith(
          currentProgress: ProgramProgress(
            programId: state.currentProgress!.programId,
            currentMissionIndex: state.currentProgress!.currentMissionIndex,
            totalMissions: state.currentProgress!.totalMissions,
            isResting: true,
            restSecondsRemaining: remaining,
            currentMissionId: state.currentProgress!.currentMissionId,
          ),
        );
      }
    });
  }

  /// Start a program
  void startProgram(String programId) {
    final program = state.programs.cast<Program?>().firstWhere(
      (p) => p?.id == programId,
      orElse: () => null,
    );
    if (program == null) return;

    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('start_program', {
      'program_id': programId,
      'mission_ids': program.missionIds,
      'rest_seconds': program.restSecondsBetween,
    });

    // Optimistic update
    state = state.copyWith(
      activeProgramId: programId,
      currentProgress: ProgramProgress(
        programId: programId,
        currentMissionIndex: 0,
        totalMissions: program.missionIds.length,
        currentMissionId: program.missionIds.first,
      ),
      clearError: true,
    );
  }

  /// Stop the active program
  void stopProgram() {
    if (state.activeProgramId == null) return;

    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('stop_program', {'program_id': state.activeProgramId});

    _restTimer?.cancel();
    state = state.copyWith(clearActiveProgram: true, clearProgress: true);

    // Also stop any active mission
    _ref.read(missionsProvider.notifier).stopMission();
  }

  /// Clear state (used on logout)
  void clearState() {
    _restTimer?.cancel();
    state = ProgramsState(programs: _predefinedPrograms);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}
