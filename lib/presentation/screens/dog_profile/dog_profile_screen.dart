import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../theme/app_theme.dart';

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
        appBar: AppBar(title: const Text('Dog Profile')),
        body: const Center(child: Text('No dog profile found')),
      );
    }

    final summary = ref.watch(dogDailySummaryProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to dog edit screen
            },
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
            const SizedBox(height: 24),

            // Launch last mission button
            _LaunchMissionButton(profile: profile),
            const SizedBox(height: 24),

            // Today's summary stats
            _TodaySummary(summary: summary),
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
    return Column(
      children: [
        // Photo avatar
        GestureDetector(
          onTap: () {
            // TODO: Implement photo picker
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceLight,
              border: Border.all(color: AppTheme.primary, width: 3),
              boxShadow: AppTheme.glowShadow(AppTheme.primary, blur: 15),
            ),
            child: profile.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      profile.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    ),
                  )
                : _buildPlaceholder(),
          ),
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          profile.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),

        // Breed and age
        Text(
          _buildSubtitle(),
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.pets, size: 40, color: AppTheme.primary),
        const SizedBox(height: 4),
        Text(
          profile.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (profile.breed != null) parts.add(profile.breed!);
    final age = profile.shortAgeString;
    if (age != null) parts.add(age);
    return parts.join(' · ');
  }
}

/// Launch last mission button
class _LaunchMissionButton extends StatelessWidget {
  final DogProfile profile;

  const _LaunchMissionButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasMission = profile.lastMissionId != null;

    return Container(
      decoration: BoxDecoration(
        gradient: hasMission ? AppTheme.primaryGradient : null,
        color: hasMission ? null : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: hasMission ? AppTheme.glowShadow(AppTheme.primary, blur: 10) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasMission
              ? () {
                  // TODO: Launch last mission
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Launching mission...')),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_filled,
                  size: 40,
                  color: hasMission ? AppTheme.background : AppTheme.textTertiary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasMission ? 'LAUNCH LAST MISSION' : 'NO RECENT MISSION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: hasMission
                              ? AppTheme.background
                              : AppTheme.textTertiary,
                        ),
                      ),
                      if (hasMission) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"Sit Training" - ran 2h ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.background.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasMission)
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.background,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's summary stats cards
class _TodaySummary extends StatelessWidget {
  final DogDailySummary summary;

  const _TodaySummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Summary",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: summary.treatCount.toString(),
                label: 'Treats',
                icon: Icons.cookie,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: summary.sitCount.toString(),
                label: 'Sits',
                icon: Icons.pets,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: summary.barkCount.toString(),
                label: 'Barks',
                icon: Icons.volume_up,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: '${(summary.goalProgress * 100).toInt()}%',
                label: 'Goal',
                icon: Icons.flag,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.glassBorder),
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
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
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
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.bar_chart,
                label: 'Stats',
                onTap: () {
                  // TODO: Navigate to analytics
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.flag,
                label: 'Goals',
                onTap: () {
                  // TODO: Navigate to goals
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.video_library,
                label: 'Videos',
                onTap: () {
                  // TODO: Navigate to video gallery
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
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.glassBorder),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to full activity/notifications
              },
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dogNotifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Center(
              child: Text(
                'No recent activity',
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.glassBorder),
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
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${notification.title}${notification.subtitle != null ? ' - ${notification.subtitle}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                _formatRelativeTime(notification.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 36,
            color: AppTheme.glassBorder,
          ),
      ],
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
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
        title: const Text('Dogs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add new dog
            },
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
                    ref.read(selectedDogProvider.notifier).state = profiles[index];
                    context.push('/dog/${profiles[index].id}');
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No dogs added yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Add new dog
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Dog'),
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
                  color: AppTheme.surfaceLighter,
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: profile.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          profile.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatar(),
                        ),
                      )
                    : _buildAvatar(),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Icon(
        Icons.pets,
        color: AppTheme.primary,
        size: 28,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (profile.breed != null) parts.add(profile.breed!);
    final age = profile.shortAgeString;
    if (age != null) parts.add(age);
    return parts.isNotEmpty ? parts.join(' · ') : 'No details';
  }
}
