import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/guardian_events_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/video/webrtc_video_view.dart';
import '../../widgets/status/battery_indicator.dart';
import '../../widgets/status/connection_badge.dart';
import '../../widgets/controls/quick_actions.dart';
import '../../widgets/controls/push_to_talk.dart';
import '../../widgets/guardian/event_feed.dart';
import '../../theme/app_theme.dart';

/// Main dashboard screen with video and quick controls
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final telemetry = ref.watch(telemetryProvider);
    final deviceId = ref.watch(deviceIdProvider);

    // Redirect only if completely disconnected from relay
    // Allow staying on home screen while waiting for robot
    if (connection.status == ConnectionStatus.disconnected ||
        connection.status == ConnectionStatus.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/connect');
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: const _DogSelector(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WIM-Z'),
            Text(
              deviceId,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          const ConnectionBadge(),
          const SizedBox(width: 8),
          BatteryIndicator(level: telemetry.battery),
          const SizedBox(width: 16),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          return Column(
            children: [
              // Video stream
              Expanded(
                flex: isLandscape ? 4 : 3,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Use WebRTC for video streaming via relay
                      const WebRTCVideoView(),

                      // Detection overlay
                      if (telemetry.dogDetected)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _DetectionChip(
                            behavior: telemetry.currentBehavior,
                            confidence: telemetry.confidence,
                          ),
                        ),

                      // Mode selector (uses optimistic state)
                      const Positioned(
                        top: 16,
                        right: 16,
                        child: _ModeSelector(),
                      ),

                      // Push-to-talk controls
                      const PushToTalkOverlay(
                        alignment: Alignment.bottomLeft,
                      ),
                    ],
                  ),
                ),
              ),

              // Quick controls or Event Feed (depending on mode)
              // In landscape: compact single row, In portrait: full controls
              // Use optimistic mode for immediate UI response
              if (ref.watch(displayModeProvider) == RobotMode.silentGuardian)
                Expanded(
                  flex: isLandscape ? 1 : 2,
                  child: const EventFeed(),
                )
              else if (isLandscape)
                // Landscape: compact navigation bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Compact quick actions
                      const Expanded(child: QuickActions()),
                      const SizedBox(width: 16),
                      // Navigation icons - Drive hidden in silent_guardian
                      _CompactNavButton(
                        icon: Icons.gamepad,
                        label: 'Drive',
                        onTap: () => context.push('/drive'),
                      ),
                      const SizedBox(width: 8),
                      _CompactNavButton(
                        icon: Icons.school,
                        label: 'Missions',
                        onTap: () => context.push('/missions'),
                      ),
                      const SizedBox(width: 8),
                      _CompactNavButton(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                )
              else
                // Portrait: full controls
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Quick action buttons
                        const QuickActions(),
                        const SizedBox(height: 16),

                        // Navigation buttons - Drive available in manual/idle/coach/mission
                        Row(
                          children: [
                            Expanded(
                              child: _NavButton(
                                icon: Icons.gamepad,
                                label: 'Drive',
                                onTap: () => context.push('/drive'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _NavButton(
                                icon: Icons.school,
                                label: 'Missions',
                                onTap: () => context.push('/missions'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _NavButton(
                                icon: Icons.settings,
                                label: 'Settings',
                                onTap: () => context.push('/settings'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Detection status chip with auto-dismiss after 3 seconds
class _DetectionChip extends StatefulWidget {
  final String? behavior;
  final double? confidence;

  const _DetectionChip({this.behavior, this.confidence});

  @override
  State<_DetectionChip> createState() => _DetectionChipState();
}

class _DetectionChipState extends State<_DetectionChip> {
  bool _isVisible = true;
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startDismissTimer();
  }

  @override
  void didUpdateWidget(_DetectionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset visibility and timer when detection updates
    if (oldWidget.behavior != widget.behavior ||
        oldWidget.confidence != widget.confidence) {
      _lastUpdate = DateTime.now();
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
      _startDismissTimer();
    }
  }

  void _startDismissTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && DateTime.now().difference(_lastUpdate).inSeconds >= 3) {
        setState(() => _isVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final color = AppTheme.getBehaviorColor(widget.behavior);
    final confidenceText =
        widget.confidence != null ? '${(widget.confidence! * 100).toInt()}%' : '';

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              widget.behavior?.toUpperCase() ?? 'DETECTED',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (confidenceText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                confidenceText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mode selector with dropdown, loading state, and event badge
class _ModeSelector extends ConsumerWidget {
  const _ModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use optimistic display mode instead of telemetry mode
    final modeState = ref.watch(modeStateProvider);
    final displayMode = modeState.displayMode;
    final isChanging = modeState.isChanging;
    final unreadCount = ref.watch(unreadEventCountProvider);
    final showBadge = displayMode == RobotMode.silentGuardian && unreadCount > 0;

    // Show error snackbar when mode change fails
    ref.listen<String?>(modeErrorProvider, (previous, error) {
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    return PopupMenuButton<RobotMode>(
      initialValue: displayMode,
      onSelected: (mode) {
        ref.read(modeStateProvider.notifier).setMode(mode);
      },
      offset: const Offset(0, 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getModeColor(displayMode).withOpacity(isChanging ? 0.6 : 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isChanging)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(_getModeIcon(displayMode), color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  displayMode.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
              ],
            ),
          ),
          // Event count badge
          if (showBadge)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      itemBuilder: (context) => RobotMode.values.map((mode) {
        return PopupMenuItem<RobotMode>(
          value: mode,
          child: Row(
            children: [
              Icon(_getModeIcon(mode), size: 20),
              const SizedBox(width: 12),
              Text(mode.label),
              if (mode == displayMode) ...[
                const Spacer(),
                const Icon(Icons.check, size: 20),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getModeColor(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle:
        return Colors.grey;
      case RobotMode.manual:
        return Colors.blue;
      case RobotMode.silentGuardian:
        return Colors.purple;
      case RobotMode.coach:
        return Colors.orange;
      case RobotMode.mission:
        return Colors.green;
    }
  }

  IconData _getModeIcon(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle:
        return Icons.pause_circle_outline;
      case RobotMode.manual:
        return Icons.gamepad;
      case RobotMode.silentGuardian:
        return Icons.visibility;
      case RobotMode.coach:
        return Icons.school;
      case RobotMode.mission:
        return Icons.flag;
    }
  }
}

/// Navigation button (portrait)
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact navigation button (landscape)
class _CompactNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompactNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dog selector in app bar
class _DogSelector extends ConsumerWidget {
  const _DogSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDog = ref.watch(selectedDogProvider);
    final allDogs = ref.watch(dogProfilesProvider);

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: allDogs.isEmpty
            ? () => context.push('/dogs/add')
            : () => _showDogPicker(context, ref, allDogs, selectedDog),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DogAvatar(profile: selectedDog, size: 36),
              const SizedBox(width: 4),
              if (allDogs.length > 1)
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDogPicker(
    BuildContext context,
    WidgetRef ref,
    List<DogProfile> dogs,
    DogProfile? current,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Dog',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/dogs/add');
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...dogs.map((dog) => ListTile(
                  leading: _DogAvatar(profile: dog, size: 44),
                  title: Text(dog.name),
                  subtitle: dog.color != DogColor.mixed
                      ? Text(dog.color.label)
                      : null,
                  trailing: current?.id == dog.id
                      ? Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    ref.read(selectedDogProvider.notifier).selectDog(dog);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Dog avatar widget
class _DogAvatar extends StatelessWidget {
  final DogProfile? profile;
  final double size;

  const _DogAvatar({required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceLight,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: profile == null
          ? Icon(Icons.add, color: AppTheme.primary, size: size * 0.5)
          : _buildPhoto(),
    );
  }

  Widget _buildPhoto() {
    // Try local photo first, then URL
    if (profile!.localPhotoPath != null) {
      final file = File(profile!.localPhotoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }
    }
    if (profile!.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile!.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        profile!.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
