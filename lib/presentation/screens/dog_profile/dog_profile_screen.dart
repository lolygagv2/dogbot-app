import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dog_profile/robot_status_card.dart';
import '../../widgets/dog_profile/talk_to_wimz_card.dart';
import '../../widgets/dog_profile/weekly_summary_card.dart';
import '../../widgets/summary/today_card.dart';

/// Dog profile screen - central hub for a dog's info, stats, and quick actions
class DogProfileScreen extends ConsumerWidget {
  final String? dogId;

  const DogProfileScreen({super.key, this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If dogId provided, use it; otherwise use selected dog
    final profile = dogId != null
        ? ref.watch(dogProfileProvider(dogId!))
        : ref.watch(selectedDogProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.dogProfileTitle)),
        body: Center(child: Text(context.l10n.dogProfileNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dogProfileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.dogProfileEditTooltip,
            onPressed: () => context.push('/dog/${profile.id}/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dog header with photo
            _DogHeader(profile: profile),
            const SizedBox(height: 16),

            // Robot state (2026-11-06: pairing is optional — "No robot
            // paired" is a normal state here, with a Pair button).
            const RobotStatusCard(),
            const SizedBox(height: 12),

            // Hold-to-talk → relay voice agent (POST /agent/utterance);
            // reply plays on the robot, or on the phone if it's offline.
            const TalkToWimzCard(),
            const SizedBox(height: 24),

            // Launch last mission button
            _LaunchMissionButton(profile: profile),
            const SizedBox(height: 24),

            // Today card — GET /summary/{dog}/{date}; falls back to the
            // feed-derived counts (the old _TodaySummary numbers) on 404.
            TodayCard(dogId: profile.id, dogName: profile.name),
            const SizedBox(height: 24),

            // Metrics dashboard
            _MetricsDashboard(dogId: profile.id),
            const SizedBox(height: 24),

            // Robot 386aef0: per-dog weekly summary (barks by type, treats,
            // coaching, guardian) pulled live from the robot
            DogWeeklySummaryCard(dogId: profile.id, dogName: profile.name),
            const SizedBox(height: 24),

            // Quick actions
            _QuickActionsGrid(dogId: profile.id),
            const SizedBox(height: 24),

            // Recent activity
            _RecentActivity(dogId: profile.id),
          ],
        ),
      ),
    );
  }
}

/// Dog header with photo and basic info
class _DogHeader extends StatelessWidget {
  final DogProfile profile;

  const _DogHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Photo avatar — tapping opens the edit screen, which owns the
        // image_picker flow (avoids duplicating photo-pick logic here).
        GestureDetector(
          onTap: () => context.push('/dog/${profile.id}/edit'),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: w.surfaceRaised,
              border: Border.all(color: cs.primary, width: 3),
            ),
            child: _buildPhoto(context),
          ),
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          profile.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),

        // Breed and age
        Text(
          _buildSubtitle(context),
          style: TextStyle(
            fontSize: 14,
            color: w.inkMuted,
          ),
        ),
        // Relay 2026-11-07: placeholder dog created when a robot was paired
        // before any dog existed — prompt for a real name (same id/history).
        if (profile.isPlaceholder) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.push('/dog/${profile.id}/edit'),
            icon: const Icon(Icons.drive_file_rename_outline, size: 18),
            label: Text(context.l10n.dogNameYourDog),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoto(BuildContext context) {
    // Try local photo first, then URL
    if (profile.localPhotoPath != null) {
      final file = File(profile.localPhotoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
            // Build 32: Use photoVersion as key to force cache refresh
            key: ValueKey('photo_${profile.id}_${profile.photoVersion}'),
            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
          ),
        );
      }
    }
    if (profile.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile.photoUrl!,
          fit: BoxFit.cover,
          key: ValueKey('photo_url_${profile.id}_${profile.photoVersion}'),
          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
        ),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.pets, size: 40, color: cs.primary),
        const SizedBox(height: 4),
        Text(
          profile.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ],
    );
  }

  String _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (profile.breed != null && profile.breed!.isNotEmpty) {
      parts.add(profile.breed!);
    }
    final age = profile.localizedShortAge(context.l10n);
    if (age != null) parts.add(age);
    return parts.join(' · ');
  }
}

/// Launch last mission button
class _LaunchMissionButton extends ConsumerWidget {
  final DogProfile profile;

  const _LaunchMissionButton({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);
    final activeMission = missionsState.activeMission;
    final hasMission = profile.lastMissionId != null;
    final hasActive = activeMission != null;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    final isLive = hasMission || hasActive;
    // Live = solid primary fill (was a gradient + glow); idle = flat card.
    final fg = isLive ? cs.onPrimary : w.inkMuted;

    return Container(
      decoration: BoxDecoration(
        color: isLive ? cs.primary : w.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: isLive ? null : Border.all(color: w.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasActive
              ? () {
                  // Show active mission
                  context.push('/missions/${activeMission.id}');
                }
              : hasMission
                  ? () {
                      // Start the last mission
                      ref.read(missionsProvider.notifier).startMission(profile.lastMissionId!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.dogProfileMissionStarted)),
                      );
                    }
                  : () {
                      // Navigate to missions list
                      context.go('/missions');
                    },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  hasActive ? Icons.play_circle : Icons.play_circle_filled,
                  size: 40,
                  color: fg,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActive
                            ? context.l10n.dogProfileMissionActive
                            : hasMission
                                ? context.l10n.dogProfileLaunchLastMission
                                : context.l10n.dogProfileStartAMission,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: fg,
                        ),
                      ),
                      if (hasActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          activeMission.localizedName(context.l10n),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual stat card
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: w.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: w.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: w.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metrics dashboard with day/week/all toggle
class _MetricsDashboard extends ConsumerWidget {
  final String dogId;

  const _MetricsDashboard({required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dogAnalyticsProvider(dogId));
    final notifier = ref.read(dogAnalyticsProvider(dogId).notifier);
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.dogProfileMetrics,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            // Range toggle
            Container(
              decoration: BoxDecoration(
                color: w.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: w.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RangeChip(
                    label: context.l10n.dogProfileRangeDay,
                    isSelected: analytics.range == AnalyticsRange.today,
                    onTap: () => notifier.setRange(AnalyticsRange.today),
                  ),
                  _RangeChip(
                    label: context.l10n.dogProfileRangeWeek,
                    isSelected: analytics.range == AnalyticsRange.week,
                    onTap: () => notifier.setRange(AnalyticsRange.week),
                  ),
                  _RangeChip(
                    label: context.l10n.dogProfileRangeAll,
                    isSelected: analytics.range == AnalyticsRange.lifetime,
                    onTap: () => notifier.setRange(AnalyticsRange.lifetime),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Metrics grid
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: analytics.treatCount.toString(),
                label: context.l10n.dogProfileStatTreats,
                icon: Icons.cookie,
                color: w.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: analytics.detectionCount.toString(),
                label: context.l10n.dogProfileStatDetections,
                icon: Icons.visibility,
                color: w.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: '${analytics.missionsSucceeded}/${analytics.missionsAttempted}',
                label: context.l10n.dogProfileStatMissions,
                icon: Icons.flag,
                color: w.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: analytics.missionsAttempted > 0
                    ? '${(analytics.successRate * 100).toInt()}%'
                    : '--',
                label: context.l10n.dogProfileStatSuccess,
                icon: Icons.check_circle,
                color: w.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: context.l10n.dogProfileActiveMinutes(analytics.activeMinutes),
                label: context.l10n.dogProfileStatActive,
                icon: Icons.timer,
                color: w.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: analytics.coachRewards.toString(),
                label: context.l10n.dogProfileStatCoach,
                icon: Icons.school,
                color: w.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              ref.read(activityTabIndexProvider.notifier).state = 0;
              context.go('/activity');
            },
            icon: const Icon(Icons.bar_chart, size: 18),
            label: Text(context.l10n.dogProfileViewDashboard),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Range toggle chip
class _RangeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? cs.onPrimary : context.wimz.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Quick actions grid
class _QuickActionsGrid extends StatelessWidget {
  final String dogId;

  const _QuickActionsGrid({required this.dogId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.dogProfileQuickActions,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.mic,
                label: context.l10n.dogProfileActionVoice,
                onTap: () {
                  // Use standalone route with extra data for reliability
                  context.push('/voice-setup', extra: {'dogId': dogId});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.bar_chart,
                label: context.l10n.dogProfileActionStats,
                onTap: () {
                  // Metrics dashboard is inline above — show a hint
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.dogProfileMetricsHint),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: w.surfaceRaised,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: w.line),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Column(
            children: [
              Icon(icon, color: cs.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: w.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recent activity list
class _RecentActivity extends ConsumerWidget {
  final String dogId;

  const _RecentActivity({required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final dogNotifications = notifications
        .where((n) => n.dogId == dogId)
        .take(5)
        .toList();
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.dogProfileRecentActivity,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                // Jump to the Activity screen's Events tab (index 1).
                ref.read(activityTabIndexProvider.notifier).state = 1;
                context.go('/activity');
              },
              child: Text(context.l10n.dogProfileSeeAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dogNotifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: w.surfaceRaised,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: w.line),
            ),
            child: Center(
              child: Text(
                context.l10n.dogProfileNoRecentActivity,
                style: TextStyle(color: w.inkMuted),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: w.surfaceRaised,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: w.line),
            ),
            child: Column(
              children: dogNotifications.map((notification) {
                final isLast = notification == dogNotifications.last;
                return _ActivityItem(
                  notification: notification,
                  showDivider: !isLast,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Individual activity item
class _ActivityItem extends StatelessWidget {
  final dynamic notification;
  final bool showDivider;

  const _ActivityItem({
    required this.notification,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${notification.title}${notification.subtitle != null ? ' - ${notification.subtitle}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: w.inkMuted,
                  ),
                ),
              ),
              Text(
                _formatRelativeTime(context, notification.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: w.inkMuted,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 36,
            color: w.line,
          ),
      ],
    );
  }

  String _formatRelativeTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return context.l10n.dogProfileRelMinutes(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return context.l10n.dogProfileRelHours(diff.inHours);
    } else {
      return context.l10n.dogProfileRelDays(diff.inDays);
    }
  }
}

/// Dogs list screen - shows all dog profiles
class DogsListScreen extends ConsumerWidget {
  const DogsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(dogProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dogsListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/dogs/add'),
          ),
        ],
      ),
      body: profiles.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                return _DogListTile(
                  profile: profiles[index],
                  onTap: () {
                    ref.read(selectedDogProvider.notifier).selectDog(profiles[index]);
                    context.push('/dog/${profiles[index].id}');
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final w = context.wimz;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 64,
            color: w.inkMuted,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.dogsListEmpty,
            style: TextStyle(
              color: w.inkMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/dogs/add'),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addDogTitle),
          ),
        ],
      ),
    );
  }
}

/// Dog list tile for the dogs list
class _DogListTile extends StatelessWidget {
  final DogProfile profile;
  final VoidCallback onTap;

  const _DogListTile({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: w.surfaceSunken,
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: _buildPhoto(context),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.isPlaceholder
                          ? context.l10n.dogNameYourDog
                          : _buildSubtitle(context),
                      style: TextStyle(
                        fontSize: 13,
                        color: profile.isPlaceholder
                            ? cs.primary
                            : w.inkMuted,
                        fontWeight: profile.isPlaceholder
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: w.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    // Try local photo first, then URL
    if (profile.localPhotoPath != null) {
      final file = File(profile.localPhotoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 56,
            height: 56,
            // Build 32: Use photoVersion as key to force cache refresh
            key: ValueKey('list_photo_${profile.id}_${profile.photoVersion}'),
            errorBuilder: (_, __, ___) => _buildAvatar(context),
          ),
        );
      }
    }
    if (profile.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile.photoUrl!,
          fit: BoxFit.cover,
          key: ValueKey('list_photo_url_${profile.id}_${profile.photoVersion}'),
          errorBuilder: (_, __, ___) => _buildAvatar(context),
        ),
      );
    }
    return _buildAvatar(context);
  }

  Widget _buildAvatar(BuildContext context) {
    return Center(
      child: Icon(
        Icons.pets,
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
    );
  }

  String _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (profile.breed != null) parts.add(profile.breed!);
    final age = profile.localizedShortAge(context.l10n);
    if (age != null) parts.add(age);
    return parts.isNotEmpty ? parts.join(' · ') : context.l10n.dogsListNoDetails;
  }
}
