import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mission.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../theme/app_theme.dart';

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);
    final activeMission = missionsState.activeMission;

    return Scaffold(
      appBar: AppBar(title: const Text('Training Missions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active mission card (if any)
          if (activeMission != null) ...[
            _ActiveMissionCard(
              mission: activeMission,
              progress: missionsState.activeProgress,
              rewards: missionsState.activeRewards,
              onStop: () => ref.read(missionsProvider.notifier).stopMission(),
            ),
            const SizedBox(height: 24),
            Text(
              'All Missions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
          ],

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
                hasOtherActive: missionsState.hasActiveMission && mission.id != missionsState.activeMissionId,
                onTap: () => context.push('/missions/${mission.id}'),
              ),
            )),
        ],
      ),
    );
  }
}

/// Card showing the currently active mission with progress
class _ActiveMissionCard extends StatelessWidget {
  final Mission mission;
  final double progress;
  final int rewards;
  final VoidCallback onStop;

  const _ActiveMissionCard({
    required this.mission,
    required this.progress,
    required this.rewards,
    required this.onStop,
  });

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
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% complete',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$rewards/${mission.dailyLimit} treats',
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
