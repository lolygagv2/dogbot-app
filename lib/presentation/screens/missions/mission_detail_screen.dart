import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/missions_provider.dart';
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
        appBar: AppBar(title: const Text('Mission')),
        body: const Center(child: Text('Mission not found')),
      );
    }

    final isThisActive = missionsState.activeMissionId == missionId;
    final hasOtherActive = missionsState.hasActiveMission && !isThisActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(mission.name),
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
                mission.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (mission.description != null)
              Center(
                child: Text(
                  mission.description!,
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
              title: 'Mission Details',
              children: [
                _DetailRow(label: 'Target Behavior', value: mission.targetBehavior.toUpperCase()),
                _DetailRow(label: 'Hold Duration', value: '${mission.requiredDuration.toStringAsFixed(0)}s'),
                _DetailRow(label: 'Cooldown', value: '${mission.cooldownSeconds}s between rewards'),
                _DetailRow(label: 'Daily Limit', value: '${mission.dailyLimit} treats'),
              ],
            ),
            const SizedBox(height: 16),

            // Progress section (if active)
            if (isThisActive) ...[
              _DetailSection(
                title: 'Progress',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: missionsState.activeProgress,
                            backgroundColor: AppTheme.glassBorder,
                            valueColor: const AlwaysStoppedAnimation(Colors.green),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(missionsState.activeProgress * 100).toInt()}% complete',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            Text(
                              '${missionsState.activeRewards}/${mission.dailyLimit} treats given',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Requirements
            _DetailSection(
              title: 'How It Works',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BulletPoint('WIM-Z watches for the "${mission.targetBehavior}" behavior'),
                      _BulletPoint('Dog must hold for ${mission.requiredDuration.toStringAsFixed(0)} seconds'),
                      _BulletPoint('Treat is dispensed automatically on success'),
                      _BulletPoint('${mission.cooldownSeconds}s cooldown between rewards'),
                      _BulletPoint('Up to ${mission.dailyLimit} treats per session'),
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
                label: const Text('Stop Mission'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              FilledButton.icon(
                onPressed: (!isConnected || hasOtherActive)
                    ? null
                    : () {
                        ref.read(missionsProvider.notifier).startMission(missionId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${mission.name} started')),
                        );
                      },
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  !isConnected
                      ? 'Robot Not Connected'
                      : hasOtherActive
                          ? 'Another Mission Active'
                          : 'Start Mission',
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
