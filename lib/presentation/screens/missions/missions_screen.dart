import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../data/models/program.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/programs_provider.dart';
import '../../theme/app_theme.dart';

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);
    final programsState = ref.watch(programsProvider);
    final coachState = ref.watch(coachProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);
    final activeMission = missionsState.activeMission;
    final activeProgram = programsState.activeProgram;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'Training History',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Coach Mode quick-access card
          _CoachModeCard(
            isCoaching: coachState.isActive,
            isConnected: isConnected,
            hasActiveTraining: programsState.hasActiveProgram || missionsState.hasActiveMission,
            onTap: () => context.push('/coach'),
          ),
          const SizedBox(height: 24),

          // Active program card (if any)
          if (activeProgram != null) ...[
            _ActiveProgramCard(
              program: activeProgram,
              progress: programsState.currentProgress,
              missions: missionsState.missions,
              onStop: () => ref.read(programsProvider.notifier).stopProgram(),
            ),
            const SizedBox(height: 24),
          ]
          // Active mission card (if any, and no active program)
          else if (activeMission != null) ...[
            _ActiveMissionCard(
              mission: activeMission,
              progress: missionsState.activeProgress,
              rewards: missionsState.activeRewards,
              status: missionsState.activeStatus,
              stageDisplay: missionsState.stageDisplay,
              statusDisplay: missionsState.statusDisplay,
              trick: missionsState.activeTrick,
              dogName: missionsState.activeDogName,
              onStop: () => ref.read(missionsProvider.notifier).stopMission(),
            ),
            const SizedBox(height: 24),
          ],

          // Programs section
          Text(
            'Training Programs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Multi-mission sequences with rest periods',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          ...programsState.programs.map((program) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProgramCard(
              program: program,
              missions: missionsState.missions,
              isActive: program.id == programsState.activeProgramId,
              isConnected: isConnected,
              hasOtherActive: programsState.hasActiveProgram || missionsState.hasActiveMission,
              onTap: () => context.push('/programs/${program.id}'),
            ),
          )),

          const SizedBox(height: 24),

          // Missions section
          Text(
            'Individual Missions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Single training sessions',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 12),

          // Mission list
          if (missionsState.missions.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 60),
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No missions configured', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ...missionsState.missions.map((mission) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MissionCard(
                mission: mission,
                isActive: mission.id == missionsState.activeMissionId,
                isConnected: isConnected,
                hasOtherActive: (missionsState.hasActiveMission && mission.id != missionsState.activeMissionId) || programsState.hasActiveProgram,
                onTap: () => context.push('/missions/${mission.id}'),
              ),
            )),
        ],
      ),
    );
  }
}

/// Card showing the currently active mission with progress (Build 31)
class _ActiveMissionCard extends StatelessWidget {
  final Mission mission;
  final double progress;
  final int rewards;
  final MissionStatus status;
  final String? stageDisplay;
  final String? statusDisplay;
  final String? trick;
  final String? dogName;
  final VoidCallback onStop;

  const _ActiveMissionCard({
    required this.mission,
    required this.progress,
    required this.rewards,
    required this.status,
    this.stageDisplay,
    this.statusDisplay,
    this.trick,
    this.dogName,
    required this.onStop,
  });

  Color _progressColorForStatus() {
    switch (status) {
      case MissionStatus.watching:
        return Colors.lightBlue;
      case MissionStatus.success:
      case MissionStatus.completed:
        return Colors.greenAccent;
      case MissionStatus.failed:
        return Colors.orange;
      case MissionStatus.waitingForDog:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop, color: Colors.white70, size: 18),
                  label: const Text(
                    'Stop',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mission.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (mission.description != null) ...[
              const SizedBox(height: 4),
              Text(
                mission.description!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Stage display (Build 31)
            if (stageDisplay != null) ...[
              Text(
                stageDisplay!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(_progressColorForStatus()),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status display (Build 31)
                if (statusDisplay != null && statusDisplay!.isNotEmpty)
                  Text(
                    statusDisplay!,
                    style: TextStyle(
                      color: _progressColorForStatus(),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    '${(progress * 100).toInt()}% complete',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                Row(
                  children: [
                    if (dogName != null) ...[
                      Icon(Icons.pets, size: 14, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        dogName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.cookie, size: 14, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '$rewards',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mission card for the mission list
class _MissionCard extends StatelessWidget {
  final Mission mission;
  final bool isActive;
  final bool isConnected;
  final bool hasOtherActive;
  final VoidCallback onTap;

  const _MissionCard({
    required this.mission,
    required this.isActive,
    required this.isConnected,
    required this.hasOtherActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getMissionIcon(mission.targetBehavior),
                  color: isActive ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.name, style: Theme.of(context).textTheme.titleMedium),
                    if (mission.description != null)
                      Text(
                        mission.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(icon: Icons.pets, label: mission.targetBehavior),
                        const SizedBox(width: 8),
                        _InfoChip(icon: Icons.cookie, label: '${mission.rewardsGiven}/${mission.dailyLimit}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.play_circle, color: Colors.green, size: 28)
              else if (hasOtherActive)
                Icon(Icons.block, color: Colors.grey.shade400, size: 24)
              else
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMissionIcon(String behavior) {
    switch (behavior.toLowerCase()) {
      case 'sit': return Icons.airline_seat_recline_normal;
      case 'down':
      case 'lie': return Icons.hotel;
      case 'stand': return Icons.accessibility_new;
      case 'stay': return Icons.timer;
      case 'quiet':
      case 'bark': return Icons.volume_off;
      default: return Icons.school;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Program card for the programs list
class _ProgramCard extends StatelessWidget {
  final Program program;
  final List<Mission> missions;
  final bool isActive;
  final bool isConnected;
  final bool hasOtherActive;
  final VoidCallback onTap;

  const _ProgramCard({
    required this.program,
    required this.missions,
    required this.isActive,
    required this.isConnected,
    required this.hasOtherActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: hasOtherActive && !isActive ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        )
                      : LinearGradient(
                          colors: [Colors.purple.shade100, Colors.purple.shade200],
                        ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProgramIcon(program.iconName),
                  color: isActive ? Colors.white : Colors.purple.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      program.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(icon: Icons.playlist_play, label: '${program.missionIds.length} missions'),
                        const SizedBox(width: 8),
                        _InfoChip(icon: Icons.timer, label: '${program.restSecondsBetween}s rest'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.play_circle, color: Colors.purple, size: 28)
              else if (hasOtherActive)
                Icon(Icons.block, color: Colors.grey.shade400, size: 24)
              else
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getProgramIcon(String? iconName) {
    switch (iconName) {
      case 'pets':
        return Icons.pets;
      case 'school':
        return Icons.school;
      case 'self_improvement':
        return Icons.self_improvement;
      default:
        return Icons.auto_awesome;
    }
  }
}

/// Active program card showing current progress
class _ActiveProgramCard extends StatelessWidget {
  final Program program;
  final ProgramProgress? progress;
  final List<Mission> missions;
  final VoidCallback onStop;

  const _ActiveProgramCard({
    required this.program,
    this.progress,
    required this.missions,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = progress?.currentMissionIndex ?? 0;
    final isResting = progress?.isResting ?? false;
    final restSeconds = progress?.restSecondsRemaining ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_play, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'PROGRAM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop, color: Colors.white70, size: 18),
                  label: const Text(
                    'Stop',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              program.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              program.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Mission sequence display
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: program.missionIds.length,
                itemBuilder: (context, index) {
                  final missionId = program.missionIds[index];
                  final mission = missions.cast<Mission?>().firstWhere(
                    (m) => m?.id == missionId,
                    orElse: () => null,
                  );
                  final name = mission?.name ?? missionId.replaceAll('_', ' ');
                  final isCurrentMission = index == currentIndex;
                  final isCompleted = index < currentIndex;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentMission
                          ? Colors.white.withOpacity(0.3)
                          : isCompleted
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: isCurrentMission
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16)
                        else if (isCurrentMission)
                          const Icon(Icons.play_circle, color: Colors.white, size: 16)
                        else
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: Colors.white.withOpacity(isCompleted || isCurrentMission ? 1.0 : 0.6),
                            fontSize: 12,
                            fontWeight: isCurrentMission ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress?.progress ?? 0.0,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(
                  isResting ? Colors.amber : Colors.white,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isResting)
                  Row(
                    children: [
                      const Icon(Icons.pause_circle, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Rest break: ${restSeconds}s',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Mission ${currentIndex + 1} of ${program.missionIds.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '${((progress?.progress ?? 0.0) * 100).toInt()}% complete',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Coach Mode quick-access card
class _CoachModeCard extends StatelessWidget {
  final bool isCoaching;
  final bool isConnected;
  final bool hasActiveTraining;
  final VoidCallback onTap;

  const _CoachModeCard({
    required this.isCoaching,
    required this.isConnected,
    required this.hasActiveTraining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = isConnected && !hasActiveTraining;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canStart || isCoaching ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isCoaching
                ? LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCoaching
                      ? Colors.white.withOpacity(0.2)
                      : Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility,
                  color: isCoaching ? Colors.white : Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coach Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCoaching ? Colors.white : null,
                      ),
                    ),
                    Text(
                      isCoaching
                          ? 'Watching for good behaviors...'
                          : 'Auto-reward when your dog performs tricks',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCoaching
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCoaching)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasActiveTraining)
                Icon(Icons.block, color: Colors.grey.shade400, size: 24)
              else
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
