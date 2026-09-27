import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

class MissionDetailScreen extends ConsumerWidget {
  final String missionId;

  const MissionDetailScreen({super.key, required this.missionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(missionByIdProvider(missionId));
    final missionsState = ref.watch(missionsProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);

    if (mission == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.missionDetailTitle)),
        body: Center(child: Text(context.l10n.missionDetailNotFound)),
      );
    }

    final isThisActive = missionsState.activeMissionId == missionId;
    final hasOtherActive = missionsState.hasActiveMission && !isThisActive;
    final isStarting = isThisActive && missionsState.currentProgress?.status == 'starting';

    // Navigate to drive only when robot confirms mission started (not optimistically)
    ref.listen<MissionsState>(missionsProvider, (prev, next) {
      final wasStarting = prev?.activeMissionId == missionId &&
          prev?.currentProgress?.status == 'starting';
      final isNowRunning = next.activeMissionId == missionId &&
          next.currentProgress?.status != 'starting' &&
          next.currentProgress?.status != 'error' &&
          next.hasActiveMission;

      if (wasStarting && isNowRunning && context.mounted) {
        context.go('/home');
        context.push('/drive');
      }

      // Show error snackbar if mission failed to start
      if (next.error != null && prev?.error != next.error && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(mission.localizedName(context.l10n)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mission icon and name header
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isThisActive
                      ? Colors.green.withOpacity(0.2)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isThisActive ? Colors.green : AppTheme.glassBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getMissionIcon(mission.targetBehavior),
                  size: 40,
                  color: isThisActive ? Colors.green : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                mission.localizedName(context.l10n),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (mission.localizedDescription(context.l10n) != null)
              Center(
                child: Text(
                  mission.localizedDescription(context.l10n)!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Details section
            _DetailSection(
              title: context.l10n.missionDetailSectionDetails,
              children: [
                _DetailRow(label: context.l10n.missionDetailTargetBehavior, value: behaviorDisplayName(context.l10n, mission.targetBehavior).toUpperCase()),
                _DetailRow(label: context.l10n.missionDetailHoldDuration, value: context.l10n.missionDetailSecondsShort(mission.requiredDuration.toStringAsFixed(0))),
                _DetailRow(label: context.l10n.missionDetailCooldown, value: context.l10n.missionDetailCooldownValue(mission.cooldownSeconds)),
                _DetailRow(label: context.l10n.missionDetailDailyLimit, value: context.l10n.missionDetailTreatsCount(mission.dailyLimit)),
              ],
            ),
            const SizedBox(height: 16),

            // Progress section (if active)
            if (isThisActive) ...[
              _DetailSection(
                title: context.l10n.missionDetailProgress,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: missionsState.activeProgress,
                            backgroundColor: AppTheme.glassBorder,
                            valueColor: AlwaysStoppedAnimation(
                              _statusColor(missionsState.activeStatus),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.missionsPercentComplete((missionsState.activeProgress * 100).toInt()),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            Text(
                              context.l10n.missionDetailTreatsGiven(missionsState.activeRewards, mission.dailyLimit),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        // Status indicator + trick + stage (Build 31)
                        if ((missionsState.currentProgress?.localizedStatus(context.l10n) ?? '').isNotEmpty ||
                            missionsState.activeTrick != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if ((missionsState.currentProgress?.localizedStatus(context.l10n) ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(missionsState.activeStatus).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _statusColor(missionsState.activeStatus).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    missionsState.currentProgress!.localizedStatus(context.l10n),
                                    style: TextStyle(
                                      color: _statusColor(missionsState.activeStatus),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (missionsState.activeTrick != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  behaviorDisplayName(context.l10n, missionsState.activeTrick),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (missionsState.currentProgress?.localizedStage(context.l10n) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            missionsState.currentProgress!.localizedStage(context.l10n)!,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Requirements
            _DetailSection(
              title: context.l10n.missionDetailHowItWorks,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BulletPoint(context.l10n.missionDetailBulletWatches(mission.targetBehavior)),
                      _BulletPoint(context.l10n.missionDetailBulletHold(mission.requiredDuration.toStringAsFixed(0))),
                      _BulletPoint(context.l10n.missionDetailBulletTreat),
                      _BulletPoint(context.l10n.missionDetailBulletCooldown(mission.cooldownSeconds)),
                      _BulletPoint(context.l10n.missionDetailBulletLimit(mission.dailyLimit)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Action button
            if (isThisActive)
              FilledButton.icon(
                onPressed: () {
                  ref.read(missionsProvider.notifier).stopMission();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop),
                label: Text(context.l10n.missionDetailStopMission),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              FilledButton.icon(
                onPressed: (!isConnected || hasOtherActive || isStarting)
                    ? null
                    : () {
                        ref.read(missionsProvider.notifier).startMission(missionId);
                        // Don't navigate — ref.listen above will navigate
                        // when robot confirms mission started
                      },
                icon: isStarting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  !isConnected
                      ? context.l10n.missionDetailRobotNotConnected
                      : hasOtherActive
                          ? context.l10n.missionDetailAnotherActive
                          : isStarting
                              ? context.l10n.missionDetailStarting
                              : context.l10n.missionDetailStartMission,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _statusColor(MissionStatus status) {
    switch (status) {
      case MissionStatus.watching:
        return Colors.lightBlue;
      case MissionStatus.success:
      case MissionStatus.completed:
        return Colors.green;
      case MissionStatus.failed:
        return Colors.orange;
      case MissionStatus.waitingForDog:
        return Colors.amber;
      case MissionStatus.greeting:
      case MissionStatus.command:
        return Colors.cyan;
      case MissionStatus.retry:
        return Colors.deepOrange;
      default:
        return Colors.green;
    }
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

/// Section container with title
class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// Detail row with label and value
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bullet point text
class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
