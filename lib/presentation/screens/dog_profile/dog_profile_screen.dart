import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
    // Capture values BEFORE any async gaps (same pattern as _confirmDelete)
    final profileId = widget.profile.id;
    final notifier = ref.read(dogProfilesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    // Show source picker as a dialog ON TOP of the settings sheet (don't pop first)
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Photo Source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
            ),
          ),
        ],
      ),
    );

    if (source == null) {
      print('[PHOTO] User cancelled source selection');
      return;
    }

    print('[PHOTO] Selected source: $source');
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);

    if (image == null) {
      print('[PHOTO] User cancelled image picker');
      return;
    }

    print('[PHOTO] Image picked: ${image.path}');

    try {
      // Copy to permanent location before saving
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/dog_photos');
      await photosDir.create(recursive: true);

      final permanentPath = '${photosDir.path}/$profileId.jpg';
      print('[PHOTO] Permanent path: $permanentPath');

      // Delete old photo if exists
      final oldFile = File(permanentPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
        print('[PHOTO] Deleted old photo');
      }

      // Copy new photo to permanent location
      final sourceFile = File(image.path);
      final sourceSize = await sourceFile.length();
      print('[PHOTO] Source file size: $sourceSize bytes');

      await sourceFile.copy(permanentPath);
      print('[PHOTO] Copied to permanent location');

      // Verify the copy
      final newFile = File(permanentPath);
      if (await newFile.exists()) {
        final newSize = await newFile.length();
        print('[PHOTO] Verified: new file exists, size: $newSize bytes');
      } else {
        print('[PHOTO] ERROR: File copy failed - destination does not exist');
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save photo'), backgroundColor: Colors.red),
        );
        return;
      }

      // Build 34: Clear Flutter's image cache BEFORE updating profile
      // This forces Image.file to re-read the file from disk
      print('[PHOTO] Clearing image cache to force refresh');
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Update the profile with new photo path
      print('[PHOTO] Calling updateProfilePhoto for dog $profileId');
      await notifier.updateProfilePhoto(profileId, permanentPath);
      print('[PHOTO] Profile updated successfully');

      // Close the settings bottom sheet
      if (mounted) Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (e, stackTrace) {
      print('[PHOTO] ERROR: $e');
      print('[PHOTO] Stack: $stackTrace');
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRenameDialog() {
    // Capture values before any async gaps
    final profile = widget.profile;
    final notifier = ref.read(dogProfilesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    // Show dialog on top of the bottom sheet
    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController(text: profile.name);
        return AlertDialog(
          title: const Text('Rename Dog'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter dog name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != profile.name) {
                  await notifier.updateProfile(
                    profile.copyWith(name: newName),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text('Renamed to $newName')),
                  );
                }
                // Close dialog
                Navigator.pop(ctx);
                // Close the settings bottom sheet
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showBreedDialog() {
    // Capture values before any async gaps (same pattern as _confirmDelete)
    final profile = widget.profile;
    final notifier = ref.read(dogProfilesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    // Show dialog on top of the bottom sheet
    showDialog(
      context: context,
      builder: (ctx) {
        final breedController = TextEditingController(text: profile.breed ?? '');
        return AlertDialog(
          title: const Text('Edit Breed'),
          content: TextField(
            controller: breedController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Breed',
              hintText: 'e.g. Golden Retriever',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newBreed = breedController.text.trim();
                await notifier.updateProfile(
                  profile.copyWith(breed: newBreed.isEmpty ? null : newBreed),
                );
                // Close dialog
                Navigator.pop(ctx);
                // Close the settings bottom sheet
                if (mounted) Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Breed updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    // Capture values before any async gaps or pops
    final profileId = widget.profile.id;
    final profileName = widget.profile.name;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(dogProfilesProvider.notifier);

    // Show dialog on top of the bottom sheet (don't pop sheet first)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dog?'),
        content: Text(
          'Are you sure you want to delete $profileName? '
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
              await notifier.removeProfile(profileId);
              // Close dialog
              Navigator.pop(ctx);
              // Close the settings bottom sheet
              if (mounted) Navigator.pop(context);
              // Navigate to dogs list
              router.go('/dogs');
              messenger.showSnackBar(
                SnackBar(content: Text('$profileName deleted')),
              );
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
            // Build 32: Use photoVersion as key to force cache refresh
            key: ValueKey('photo_${profile.id}_${profile.photoVersion}'),
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
          key: ValueKey('photo_url_${profile.id}_${profile.photoVersion}'),
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
    if (profile.breed != null && profile.breed!.isNotEmpty) {
      parts.add(profile.breed!);
    }
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
                  // Use standalone route with extra data for reliability
                  context.push('/voice-setup', extra: {'dogId': dogId});
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
            // Build 32: Use photoVersion as key to force cache refresh
            key: ValueKey('list_photo_${profile.id}_${profile.photoVersion}'),
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
          key: ValueKey('list_photo_url_${profile.id}_${profile.photoVersion}'),
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
