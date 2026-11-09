import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../data/models/program.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/programs_provider.dart';
import '../../../l10n/l10n.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.missionsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: context.l10n.historyTitle,
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
              stageDisplay: missionsState.currentProgress?.localizedStage(context.l10n),
              statusDisplay: missionsState.currentProgress?.localizedStatus(context.l10n),
              trick: missionsState.activeTrick,
              dogName: missionsState.activeDogName,
              onStop: () => ref.read(missionsProvider.notifier).stopMission(),
              onDrive: () => context.push('/drive'),
            ),
            const SizedBox(height: 24),
          ],

          // Programs section
          Text(
            context.l10n.missionsProgramsHeader,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.missionsProgramsSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
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
            context.l10n.missionsIndividualHeader,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.missionsIndividualSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Mission list
          if (missionsState.missions.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Icon(Icons.school_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(context.l10n.missionsNoneConfigured, style: TextStyle(color: cs.onSurfaceVariant)),
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
  final VoidCallback onDrive;

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
    required this.onDrive,
  });

  /// Status → ink / ink-muted / signal only. The status word is always
  /// printed beside the bar, so colour never carries it alone.
  Color _progressColorForStatus(BuildContext context) {
    final w = context.wimz;
    switch (status) {
      case MissionStatus.watching:
        return w.signal; // live: robot is watching the dog
      case MissionStatus.success:
      case MissionStatus.completed:
        return w.ink;
      case MissionStatus.failed:
        return w.inkMuted;
      case MissionStatus.waitingForDog:
        return w.inkMuted;
      default:
        return w.ink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: WimzTheme.cardDecoration(context, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: WimzTheme.statusChipDecoration(context, radius: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle, color: w.signal, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.missionsActiveBadge,
                        style: TextStyle(
                          color: w.signal,
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
                  onPressed: onDrive,
                  icon: Icon(Icons.videocam, color: cs.onPrimary, size: 18),
                  label: Text(
                    context.l10n.missionsDriveButton,
                    style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onStop,
                  icon: Icon(Icons.stop, color: cs.onSurfaceVariant, size: 18),
                  label: Text(
                    context.l10n.missionsStop,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mission.localizedName(context.l10n),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (mission.localizedDescription(context.l10n) != null) ...[
              const SizedBox(height: 4),
              Text(
                mission.localizedDescription(context.l10n)!,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
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
                  color: cs.onSurfaceVariant,
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
                backgroundColor: w.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(_progressColorForStatus(context)),
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
                      color: _progressColorForStatus(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    context.l10n.missionsPercentComplete((progress * 100).toInt()),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                Row(
                  children: [
                    if (dogName != null) ...[
                      Icon(Icons.pets, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        dogName!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.cookie, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$rewards',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
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
                  color: isActive ? cs.primary : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getMissionIcon(mission.targetBehavior),
                  color: isActive ? cs.onPrimary : cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.localizedName(context.l10n), style: Theme.of(context).textTheme.titleMedium),
                    if (mission.localizedDescription(context.l10n) != null)
                      Text(
                        mission.localizedDescription(context.l10n)!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(icon: Icons.pets, label: behaviorDisplayName(context.l10n, mission.targetBehavior)),
                        const SizedBox(width: 8),
                        _InfoChip(icon: Icons.cookie, label: '${mission.rewardsGiven}/${mission.dailyLimit}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.play_circle, color: cs.primary, size: 28)
              else if (hasOtherActive)
                Icon(Icons.block, color: w.inkDisabled, size: 24)
              else
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
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
      case 'stand':
      case 'come': return Icons.accessibility_new;
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
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
                  color: isActive ? cs.primary : w.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProgramIcon(program.iconName),
                  color: isActive ? cs.onPrimary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.localizedName(context.l10n), style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      program.localizedDescription(context.l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(icon: Icons.playlist_play, label: context.l10n.missionsCountChip(program.missionIds.length)),
                        const SizedBox(width: 8),
                        _InfoChip(icon: Icons.timer, label: context.l10n.missionsRestChip(program.restSecondsBetween)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.play_circle, color: cs.primary, size: 28)
              else if (hasOtherActive)
                Icon(Icons.block, color: w.inkDisabled, size: 24)
              else
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: WimzTheme.cardDecoration(context, radius: 16),
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
                    color: w.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_play, color: cs.onSurface, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.missionsProgramBadge,
                        style: TextStyle(
                          color: cs.onSurface,
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
                  icon: Icon(Icons.stop, color: cs.onSurfaceVariant, size: 18),
                  label: Text(
                    context.l10n.missionsStop,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              program.localizedName(context.l10n),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              program.localizedDescription(context.l10n),
              style: TextStyle(
                color: cs.onSurfaceVariant,
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
                  final name = mission?.localizedName(context.l10n) ?? missionIdDisplayName(context.l10n, missionId);
                  final isCurrentMission = index == currentIndex;
                  final isCompleted = index < currentIndex;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      // Current = sunken + ink border; completed = sunken
                      // (with its check icon); pending = transparent.
                      color: isCurrentMission
                          ? w.surfaceSunken
                          : isCompleted
                              ? w.surfaceSunken
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isCurrentMission
                          ? Border.all(color: cs.onSurface, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Icon(Icons.check_circle, color: cs.onSurface, size: 16)
                        else if (isCurrentMission)
                          Icon(Icons.play_circle, color: cs.onSurface, size: 16)
                        else
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: isCompleted || isCurrentMission ? cs.onSurface : cs.onSurfaceVariant,
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
                backgroundColor: w.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(
                  isResting ? w.inkMuted : cs.primary,
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
                      Icon(Icons.pause_circle, color: cs.onSurfaceVariant, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.missionsRestBreak(restSeconds),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    context.l10n.missionsMissionOf(currentIndex + 1, program.missionIds.length),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  context.l10n.missionsPercentComplete(((progress?.progress ?? 0.0) * 100).toInt()),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canStart || isCoaching ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Coaching = sunken fill (plus the ACTIVE chip below).
            color: isCoaching ? w.surfaceSunken : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCoaching ? cs.primary : w.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility,
                  color: isCoaching ? cs.onPrimary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.missionsCoachMode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCoaching ? cs.onSurface : null,
                      ),
                    ),
                    Text(
                      isCoaching
                          ? context.l10n.missionsCoachWatching
                          : context.l10n.missionsCoachSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCoaching)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: WimzTheme.statusChipDecoration(context, radius: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle, color: w.signal, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.missionsActiveBadge,
                        style: TextStyle(
                          color: w.signal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasActiveTraining)
                Icon(Icons.block, color: w.inkDisabled, size: 24)
              else
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
