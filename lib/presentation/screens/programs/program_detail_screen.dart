import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../data/models/program.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/programs_provider.dart';
import '../../theme/app_theme.dart';

class ProgramDetailScreen extends ConsumerWidget {
  final String programId;

  const ProgramDetailScreen({super.key, required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programByIdProvider(programId));
    final programsState = ref.watch(programsProvider);
    final missionsState = ref.watch(missionsProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);
    final selectedDog = ref.watch(selectedDogProvider);

    if (program == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Program')),
        body: const Center(child: Text('Program not found')),
      );
    }

    final isActive = programsState.activeProgramId == programId;
    final hasOtherActive = (programsState.hasActiveProgram && !isActive) || missionsState.hasActiveMission;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: () => ref.read(programsProvider.notifier).stopProgram(),
              tooltip: 'Stop Program',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Program header
          _ProgramHeader(program: program, isActive: isActive),
          const SizedBox(height: 24),

          // Active progress (if running)
          if (isActive && programsState.currentProgress != null) ...[
            _ActiveProgress(
              progress: programsState.currentProgress!,
              program: program,
              missions: missionsState.missions,
            ),
            const SizedBox(height: 24),
          ],

          // Mission sequence
          Text(
            'Mission Sequence',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...program.missionIds.asMap().entries.map((entry) {
            final index = entry.key;
            final missionId = entry.value;
            final mission = missionsState.missions.cast<Mission?>().firstWhere(
              (m) => m?.id == missionId,
              orElse: () => null,
            );

            final isCurrentMission = isActive &&
                programsState.currentProgress?.currentMissionIndex == index;
            final isCompleted = isActive &&
                (programsState.currentProgress?.currentMissionIndex ?? 0) > index;

            return _MissionSequenceItem(
              index: index,
              mission: mission,
              missionId: missionId,
              isCurrentMission: isCurrentMission,
              isCompleted: isCompleted,
              showRestIndicator: index < program.missionIds.length - 1,
              restSeconds: program.restSecondsBetween,
            );
          }),
          const SizedBox(height: 24),

          // Program info
          _ProgramInfo(program: program),
          const SizedBox(height: 32),

          // Start button
          if (!isActive)
            _StartButton(
              isConnected: isConnected,
              hasOtherActive: hasOtherActive,
              selectedDog: selectedDog?.name,
              onStart: () {
                ref.read(programsProvider.notifier).startProgram(programId);
              },
            ),
        ],
      ),
    );
  }
}

class _ProgramHeader extends StatelessWidget {
  final Program program;
  final bool isActive;

  const _ProgramHeader({required this.program, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.purple.shade600, Colors.purple.shade800]
              : [Colors.purple.shade100, Colors.purple.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.2) : Colors.purple.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 32,
              color: isActive ? Colors.white : Colors.purple.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RUNNING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Text(
                  program.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.purple.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  program.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? Colors.white.withOpacity(0.9) : Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProgress extends StatelessWidget {
  final ProgramProgress progress;
  final Program program;
  final List<Mission> missions;

  const _ActiveProgress({
    required this.progress,
    required this.program,
    required this.missions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.isResting ? Icons.pause_circle : Icons.play_circle,
                color: progress.isResting ? Colors.amber : Colors.purple,
              ),
              const SizedBox(width: 8),
              Text(
                progress.isResting
                    ? 'Rest Break'
                    : 'Mission ${progress.currentMissionIndex + 1} of ${progress.totalMissions}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(
                progress.isResting ? Colors.amber : Colors.purple,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          if (progress.isResting)
            Text(
              '${progress.restSecondsRemaining} seconds until next mission',
              style: TextStyle(color: Colors.amber.shade300),
            )
          else
            Text(
              '${(progress.progress * 100).toInt()}% through program',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _MissionSequenceItem extends StatelessWidget {
  final int index;
  final Mission? mission;
  final String missionId;
  final bool isCurrentMission;
  final bool isCompleted;
  final bool showRestIndicator;
  final int restSeconds;

  const _MissionSequenceItem({
    required this.index,
    required this.mission,
    required this.missionId,
    required this.isCurrentMission,
    required this.isCompleted,
    required this.showRestIndicator,
    required this.restSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final name = mission?.name ?? missionId.replaceAll('_', ' ');
    final description = mission?.description ?? '';

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentMission
                ? Colors.purple.withOpacity(0.2)
                : isCompleted
                    ? Colors.green.withOpacity(0.1)
                    : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentMission
                  ? Colors.purple
                  : isCompleted
                      ? Colors.green
                      : AppTheme.glassBorder,
              width: isCurrentMission ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrentMission
                          ? Colors.purple
                          : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : isCurrentMission
                          ? const Icon(Icons.play_arrow, color: Colors.white, size: 18)
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCurrentMission || isCompleted
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isCurrentMission)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showRestIndicator)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${restSeconds}s rest',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProgramInfo extends StatelessWidget {
  final Program program;

  const _ProgramInfo({required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.playlist_play,
            label: 'Total Missions',
            value: '${program.missionIds.length}',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.timer,
            label: 'Rest Between Missions',
            value: '${program.restSecondsBetween} seconds',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schedule,
            label: 'Estimated Time',
            value: _estimateTime(program),
          ),
        ],
      ),
    );
  }

  String _estimateTime(Program program) {
    // Rough estimate: 2-3 minutes per mission + rest periods
    final missionMinutes = program.missionIds.length * 2.5;
    final restMinutes = (program.missionIds.length - 1) * program.restSecondsBetween / 60;
    final totalMinutes = (missionMinutes + restMinutes).round();
    return '$totalMinutes-${totalMinutes + 5} minutes';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppTheme.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool isConnected;
  final bool hasOtherActive;
  final String? selectedDog;
  final VoidCallback onStart;

  const _StartButton({
    required this.isConnected,
    required this.hasOtherActive,
    this.selectedDog,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = isConnected && !hasOtherActive;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canStart ? onStart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 28),
            label: Text(
              selectedDog != null ? 'Start with $selectedDog' : 'Start Program',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (!isConnected) ...[
          const SizedBox(height: 8),
          Text(
            'Connect to robot to start',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ] else if (hasOtherActive) ...[
          const SizedBox(height: 8),
          Text(
            'Stop current training first',
            style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
