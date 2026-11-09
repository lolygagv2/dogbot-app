import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../data/models/program.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/programs_provider.dart';
import '../../../l10n/l10n.dart';
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
        appBar: AppBar(title: Text(context.l10n.programTitle)),
        body: Center(child: Text(context.l10n.programNotFound)),
      );
    }

    final isActive = programsState.activeProgramId == programId;
    final hasOtherActive = (programsState.hasActiveProgram && !isActive) || missionsState.hasActiveMission;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.localizedName(context.l10n)),
        actions: [
          if (isActive)
            IconButton(
              // Icon-only stop (tooltip only) — plain ink, not an error state.
              icon: Icon(Icons.stop, color: cs.onSurface),
              onPressed: () => ref.read(programsProvider.notifier).stopProgram(),
              tooltip: context.l10n.programStop,
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
            context.l10n.programMissionSequence,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WimzTheme.cardDecoration(
        context,
        radius: 16,
        borderColor: isActive ? cs.primary : null,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isActive ? cs.primary : w.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 32,
              color: isActive ? cs.onPrimary : cs.onSurface,
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
                    // Live "running" status chip.
                    decoration: WimzTheme.statusChipDecoration(context, radius: 8),
                    child: Text(
                      context.l10n.programRunningBadge,
                      style: TextStyle(
                        color: w.signal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Text(
                  program.localizedName(context.l10n),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  program.localizedDescription(context.l10n),
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WimzTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.isResting ? Icons.pause_circle : Icons.play_circle,
                color: progress.isResting ? w.inkMuted : cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                progress.isResting
                    ? context.l10n.programRestBreak
                    : context.l10n.missionsMissionOf(progress.currentMissionIndex + 1, progress.totalMissions),
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
              backgroundColor: w.surfaceSunken,
              valueColor: AlwaysStoppedAnimation(
                progress.isResting ? w.inkMuted : cs.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          if (progress.isResting)
            Text(
              context.l10n.programSecondsUntilNext(progress.restSecondsRemaining),
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Text(
              context.l10n.programPercentThrough((progress.progress * 100).toInt()),
              style: TextStyle(color: cs.onSurfaceVariant),
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
    final name = mission?.localizedName(context.l10n) ?? missionIdDisplayName(context.l10n, missionId);
    final description = mission?.localizedDescription(context.l10n) ?? '';
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // Current = sunken + ink border; completed/pending = raised card.
            // The circle's check / play icon carries the state.
            color: isCurrentMission
                ? w.surfaceSunken
                : isCompleted
                    ? w.surfaceRaised
                    : w.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentMission
                  ? cs.primary
                  : isCompleted
                      ? w.lineStrong
                      : w.line,
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
                      ? cs.primary
                      : isCurrentMission
                          ? cs.primary
                          : w.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: cs.onPrimary, size: 18)
                      : isCurrentMission
                          ? Icon(Icons.play_arrow, color: cs.onPrimary, size: 18)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: cs.onSurface,
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
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
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
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.programNowBadge,
                    style: TextStyle(
                      color: cs.onPrimary,
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
                  color: w.line,
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  context.l10n.missionsRestChip(restSeconds),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
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
      decoration: WimzTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.programDetails,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.playlist_play,
            label: context.l10n.programTotalMissions,
            value: '${program.missionIds.length}',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.timer,
            label: context.l10n.programRestBetween,
            value: context.l10n.programSecondsValue(program.restSecondsBetween),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schedule,
            label: context.l10n.programEstimatedTime,
            value: _estimateTime(context, program),
          ),
        ],
      ),
    );
  }

  String _estimateTime(BuildContext context, Program program) {
    // Rough estimate: 2-3 minutes per mission + rest periods
    final missionMinutes = program.missionIds.length * 2.5;
    final restMinutes = (program.missionIds.length - 1) * program.restSecondsBetween / 60;
    final totalMinutes = (missionMinutes + restMinutes).round();
    return context.l10n.programMinutesRange(totalMinutes, totalMinutes + 5);
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canStart ? onStart : null,
            // This screen's ONE gold element: the Start hero CTA.
            style: WimzTheme.goldButtonStyle(context).copyWith(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 28),
            label: Text(
              selectedDog != null ? context.l10n.programStartWith(selectedDog!) : context.l10n.programStart,
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
            context.l10n.programConnectToStart,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ] else if (hasOtherActive) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.programStopCurrentFirst,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
