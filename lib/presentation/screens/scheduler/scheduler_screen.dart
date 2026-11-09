import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/schedule.dart';
import '../../../domain/providers/scheduler_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../l10n/l10n.dart';
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
        title: Text(context.l10n.schedulerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/scheduler/new'),
            tooltip: context.l10n.schedulerAddSchedule,
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
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedulerState.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13),
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
        label: Text(context.l10n.schedulerAddSchedule),
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
        color: context.wimz.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? context.wimz.lineStrong : context.wimz.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.schedule : Icons.schedule_outlined,
            color: isEnabled ? context.wimz.ink : context.wimz.inkMuted,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.schedulerAutoScheduler,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? context.wimz.ink : context.wimz.inkMuted,
                  ),
                ),
                Text(
                  isEnabled ? context.l10n.schedulerRunsAutomatically : context.l10n.schedulerPaused,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? context.wimz.ink : context.wimz.inkMuted,
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
              color: context.wimz.inkMuted,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.schedulerEmptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.schedulerEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wimz.inkMuted,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.schedulerAddSchedule),
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
    // §3: a row the robot says will not fire is greyed out like a paused one.
    final isActive =
        schedule.enabled && isGlobalEnabled && !schedule.willNotFire;
    final duration =
        schedule.isModeMission ? schedule.localizedDuration(context.l10n) : null;
    final nextRun = schedule.localizedNextRun(context.l10n);

    return Dismissible(
      key: Key(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.schedulerDeleteTitle),
            content: Text(context.l10n.schedulerDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                icon: const Icon(Icons.delete, size: 18),
                label: Text(context.l10n.delete),
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
          // Assistant-made entries (and mode entries) have no editable
          // mission/stages in the legacy editor; delete is via swipe.
          onTap: schedule.isFromAssistant || schedule.isModeMission
              ? null
              : () => context.push('/scheduler/${schedule.id}'),
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
                        ? context.wimz.surfaceSunken
                        : context.wimz.surfaceRaised,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.pets,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : context.wimz.inkMuted,
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
                          // Relay brief 2026-11-07 §1: the title is the
                          // mission/mode label, never the dog's name.
                          Expanded(
                            child: Text(
                              schedule.localizedTitle(context.l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? context.wimz.ink
                                    : context.wimz.inkMuted,
                              ),
                            ),
                          ),
                          if (schedule.isFromAssistant)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Tooltip(
                                message: context.l10n.schedulerByAssistant,
                                child: Icon(Icons.auto_awesome,
                                    size: 14,
                                    color: isActive
                                        ? context.wimz.ink
                                        : context.wimz.inkMuted),
                              ),
                            ),
                          if (!schedule.enabled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.wimz.surfaceSunken,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.l10n.schedulerPausedBadge,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: context.wimz.inkMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dog?.name ?? context.l10n.schedulerUnknownDog,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : context.wimz.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: context.wimz.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              duration == null
                                  ? schedule.localizedDescription(context.l10n)
                                  : '${schedule.localizedDescription(context.l10n)} · $duration',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.wimz.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (nextRun != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: isActive
                                  ? context.wimz.ink
                                  : context.wimz.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.schedulerNextRun(nextRun),
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? context.wimz.ink
                                    : context.wimz.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ] else if (schedule.willNotFire) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: context.wimz.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                schedule.reason!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.wimz.inkMuted,
                                ),
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
                      color: context.wimz.inkMuted,
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
