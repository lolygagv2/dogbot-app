import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../theme/app_theme.dart';

/// Show dog settings bottom sheet
void _showDogSettingsSheet(BuildContext context, WidgetRef ref, DogProfile profile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _DogSettingsSheet(profile: profile),
  );
}

/// Dog settings bottom sheet content
class _DogSettingsSheet extends ConsumerStatefulWidget {
  final DogProfile profile;

  const _DogSettingsSheet({required this.profile});

  @override
  ConsumerState<_DogSettingsSheet> createState() => _DogSettingsSheetState();
}

class _DogSettingsSheetState extends ConsumerState<_DogSettingsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _breedController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _breedController = TextEditingController(text: widget.profile.breed ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Dog Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Change Photo
          _SettingsOption(
            icon: Icons.camera_alt,
            label: 'Change Photo',
            onTap: () => _changePhoto(),
          ),
          const Divider(height: 1),

          // Rename Dog
          _SettingsOption(
            icon: Icons.edit,
            label: 'Rename Dog',
            onTap: () => _showRenameDialog(),
          ),
          const Divider(height: 1),

          // Edit Breed
          _SettingsOption(
            icon: Icons.pets,
            label: 'Edit Breed',
            subtitle: widget.profile.breed ?? 'Not set',
            onTap: () => _showBreedDialog(),
          ),
          const Divider(height: 1),

          // Delete Dog
          _SettingsOption(
            icon: Icons.delete_forever,
            label: 'Delete Dog',
            color: Colors.red,
            onTap: () => _confirmDelete(),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _changePhoto() async {
    Navigator.pop(context);

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (image != null) {
      await ref.read(dogProfilesProvider.notifier).updateProfilePhoto(
        widget.profile.id,
        image.path,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    }
  }

  void _showRenameDialog() {
    Navigator.pop(context);
    _nameController.text = widget.profile.name;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Dog'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter dog name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && newName != widget.profile.name) {
                await ref.read(dogProfilesProvider.notifier).updateProfile(
                  widget.profile.copyWith(name: newName),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed to $newName')),
                  );
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBreedDialog() {
    Navigator.pop(context);
    _breedController.text = widget.profile.breed ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Breed'),
        content: TextField(
          controller: _breedController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Breed',
            hintText: 'e.g. Golden Retriever',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newBreed = _breedController.text.trim();
              await ref.read(dogProfilesProvider.notifier).updateProfile(
                widget.profile.copyWith(breed: newBreed.isEmpty ? null : newBreed),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Breed updated')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dog?'),
        content: Text(
          'Are you sure you want to delete ${widget.profile.name}? '
          'This will remove all their data and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(dogProfilesProvider.notifier).removeProfile(widget.profile.id);
              Navigator.pop(ctx);
              if (mounted) {
                context.go('/dogs');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.profile.name} deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Settings option tile
class _SettingsOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsOption({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textPrimary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        label,
        style: TextStyle(color: effectiveColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: AppTheme.textTertiary))
          : null,
      trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }
}

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
            onPressed: () => _showDogSettingsSheet(context, ref, profile),
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

            // Metrics dashboard
            _MetricsDashboard(dogId: profile.id),
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
            child: _buildPhoto(),
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

  Widget _buildPhoto() {
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
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }
    }
    if (profile.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
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
class _LaunchMissionButton extends ConsumerWidget {
  final DogProfile profile;

  const _LaunchMissionButton({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);
    final activeMission = missionsState.activeMission;
    final hasMission = profile.lastMissionId != null;
    final hasActive = activeMission != null;

    return Container(
      decoration: BoxDecoration(
        gradient: (hasMission || hasActive) ? AppTheme.primaryGradient : null,
        color: (hasMission || hasActive) ? null : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: (hasMission || hasActive) ? AppTheme.glowShadow(AppTheme.primary, blur: 10) : null,
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
                        const SnackBar(content: Text('Mission started')),
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
                  color: (hasMission || hasActive)
                      ? AppTheme.background
                      : AppTheme.textTertiary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActive
                            ? 'MISSION ACTIVE'
                            : hasMission
                                ? 'LAUNCH LAST MISSION'
                                : 'START A MISSION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: (hasMission || hasActive)
                              ? AppTheme.background
                              : AppTheme.textTertiary,
                        ),
                      ),
                      if (hasActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          activeMission.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.background.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: (hasMission || hasActive)
                      ? AppTheme.background
                      : AppTheme.textTertiary,
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

/// Metrics dashboard with day/week/all toggle
class _MetricsDashboard extends ConsumerWidget {
  final String dogId;

  const _MetricsDashboard({required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dogAnalyticsProvider(dogId));
    final notifier = ref.read(dogAnalyticsProvider(dogId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            // Range toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RangeChip(
                    label: 'Day',
                    isSelected: analytics.range == AnalyticsRange.today,
                    onTap: () => notifier.setRange(AnalyticsRange.today),
                  ),
                  _RangeChip(
                    label: 'Week',
                    isSelected: analytics.range == AnalyticsRange.week,
                    onTap: () => notifier.setRange(AnalyticsRange.week),
                  ),
                  _RangeChip(
                    label: 'All',
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
                label: 'Treats',
                icon: Icons.cookie,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: analytics.detectionCount.toString(),
                label: 'Detections',
                icon: Icons.visibility,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: '${analytics.missionsSucceeded}/${analytics.missionsAttempted}',
                label: 'Missions',
                icon: Icons.flag,
                color: Colors.green,
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
                label: 'Success',
                icon: Icons.check_circle,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: '${analytics.activeMinutes}m',
                label: 'Active',
                icon: Icons.timer,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 8),
            // Spacer card to keep grid alignment
            const Expanded(child: SizedBox()),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.background : AppTheme.textSecondary,
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
                icon: Icons.mic,
                label: 'Voice',
                onTap: () {
                  context.push('/dogs/$dogId/voice');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.bar_chart,
                label: 'Stats',
                onTap: () {
                  // Metrics dashboard is inline above — show a hint
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Metrics are shown above — use Day/Week/All toggle'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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
            onPressed: () => context.push('/dogs/add'),
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
                child: _buildPhoto(),
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

  Widget _buildPhoto() {
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
            errorBuilder: (_, __, ___) => _buildAvatar(),
          ),
        );
      }
    }
    if (profile.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatar(),
        ),
      );
    }
    return _buildAvatar();
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
