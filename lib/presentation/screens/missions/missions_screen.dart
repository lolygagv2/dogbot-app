import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/datasources/robot_api.dart';
import '../../../data/models/mission.dart';
import '../../../domain/providers/connection_provider.dart';

final missionsProvider = FutureProvider<List<Mission>>((ref) async {
  if (!ref.watch(connectionProvider).isConnected) return [];
  return ref.read(robotApiProvider).getMissions();
});

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(missionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Training Missions')),
      body: missionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (missions) {
          if (missions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No missions configured', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = missions[index];
              return _MissionCard(
                mission: mission,
                onTap: () => context.push('/missions/${mission.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;

  const _MissionCard({required this.mission, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  color: mission.isActive ? Colors.green : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getMissionIcon(mission.targetBehavior),
                  color: mission.isActive ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
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
              if (mission.isActive)
                const Icon(Icons.play_circle, color: Colors.green, size: 28),
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
