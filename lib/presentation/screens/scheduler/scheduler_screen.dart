import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/schedule.dart';
import '../../../domain/providers/scheduler_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../theme/app_theme.dart';

class SchedulerScreen extends ConsumerStatefulWidget {
  const SchedulerScreen({super.key});

  @override
  ConsumerState<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends ConsumerState<SchedulerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schedulerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedulerState = ref.watch(schedulerProvider);
    final schedules = schedulerState.sortedSchedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Scheduler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/scheduler/new'),
            tooltip: 'Add Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          // Master toggle
          _MasterToggle(
            isEnabled: schedulerState.isGlobalEnabled,
            onToggle: () => ref.read(schedulerProvider.notifier).toggleGlobalEnabled(),
          ),

          // Error message
          if (schedulerState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.error.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedulerState.error!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Schedule list
          Expanded(
            child: schedulerState.isLoading && schedules.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : schedules.isEmpty
                    ? _EmptyState(onAdd: () => context.push('/scheduler/new'))
                    : RefreshIndicator(
                        onRefresh: () => ref.read(schedulerProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: schedules.length,
                          itemBuilder: (context, index) {
                            return _ScheduleCard(
                              schedule: schedules[index],
                              isGlobalEnabled: schedulerState.isGlobalEnabled,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scheduler/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }
}

class _MasterToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const _MasterToggle({
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppTheme.accent.withOpacity(0.1)
            : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? AppTheme.accent.withOpacity(0.3) : AppTheme.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.schedule : Icons.schedule_outlined,
            color: isEnabled ? AppTheme.accent : AppTheme.textTertiary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Scheduler',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  isEnabled ? 'Training runs automatically' : 'Schedules paused',
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? AppTheme.accent : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Scheduled Training',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schedule automatic training sessions\nfor your dog at specific times',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  final MissionSchedule schedule;
  final bool isGlobalEnabled;

  const _ScheduleCard({
    required this.schedule,
    required this.isGlobalEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dog = ref.watch(dogProfileProvider(schedule.dogId));
    final mission = ref.watch(missionByIdProvider(schedule.missionId));
    final isActive = schedule.enabled && isGlobalEnabled;

    return Dismissible(
      key: Key(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Schedule'),
            content: const Text('Are you sure you want to delete this schedule?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(schedulerProvider.notifier).deleteSchedule(schedule.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => context.push('/scheduler/${schedule.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Dog avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withOpacity(0.2)
                        : AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.pets,
                    color: isActive ? AppTheme.primary : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dog?.name ?? 'Unknown Dog',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (!schedule.enabled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PAUSED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mission?.name ?? schedule.missionId,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive ? AppTheme.primary : AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            schedule.scheduleDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (schedule.nextRunDisplay != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: isActive ? AppTheme.accent : AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Next: ${schedule.nextRunDisplay}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? AppTheme.accent : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Toggle & More
                Column(
                  children: [
                    Switch(
                      value: schedule.enabled,
                      onChanged: isGlobalEnabled
                          ? (_) => ref
                              .read(schedulerProvider.notifier)
                              .toggleScheduleEnabled(schedule.id)
                          : null,
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
