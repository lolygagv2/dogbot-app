import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/guardian_events_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/video/smart_video_view.dart';
import '../../widgets/video/audio_mute_toggle.dart';
import '../../widgets/status/battery_indicator.dart';
import '../../widgets/status/connection_badge.dart';
import '../../widgets/status/treat_counter_indicator.dart';
import '../../widgets/controls/quick_actions.dart';
import '../../widgets/guardian/event_feed.dart';
import '../../widgets/mission/mission_progress_overlay.dart';
import '../../theme/app_theme.dart';

/// Main dashboard screen with video and quick controls
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Connection status is shown via MainShell's reconnect banner
    // No redirect needed - user stays in app and can reconnect from banner
    final telemetry = ref.watch(telemetryProvider);
    final deviceId = ref.watch(deviceIdProvider);
    final hasPairedDevice = deviceId != AppConstants.defaultDeviceId;

    return Scaffold(
      appBar: AppBar(
        leading: const _DogSelector(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WIM-Z'),
            if (hasPairedDevice)
              Text(
                deviceId,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              )
            else
              GestureDetector(
                onTap: () => context.push('/device-pairing'),
                child: Text(
                  'Find your robot →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          const ConnectionBadge(),
          const SizedBox(width: 8),
          const TreatCounterIndicator(),
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
              // Video stream — fills available space
              Expanded(
                flex: isLandscape ? 4 : 5,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SmartVideoView(),

                      // Detection overlay (hidden during mission)
                      if (telemetry.dogDetected && !ref.watch(missionsProvider).hasActiveMission)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: IgnorePointer(
                            child: _DetectionChip(
                              behavior: telemetry.currentBehavior,
                              confidence: telemetry.confidence,
                            ),
                          ),
                        ),

                      // Unknown dog prompt — detected ArUco with no profile
                      _UnknownDogBanner(),

                      // Mission progress overlay
                      const MissionProgressOverlay(),

                      // Audio mute toggle (bottom-right)
                      const Positioned(
                        bottom: 16,
                        right: 16,
                        child: AudioMuteToggle(),
                      ),
                    ],
                  ),
                ),
              ),

              // Mode row — ALWAYS visible so user can always exit any mode
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const _ModeAndDriveRow(),
              ),

              // Controls area (below mode row)
              if (ref.watch(modeStateProvider).currentMode == RobotMode.silentGuardian)
                Expanded(
                  flex: isLandscape ? 1 : 3,
                  child: const EventFeed(),
                )
              else if (isLandscape)
                // Landscape: compact bar with quick actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const QuickActions(),
                )
              else
                // Portrait: scrollable quick actions
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: const QuickActions(),
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
              AppTheme.getBehaviorDisplayName(widget.behavior).toUpperCase(),
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

/// Banner shown when a dog with ArUco marker is detected but has no profile.
/// Positioned at top-right of video, auto-dismisses after 10s, tap to add dog.
class _UnknownDogBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_UnknownDogBanner> createState() => _UnknownDogBannerState();
}

class _UnknownDogBannerState extends ConsumerState<_UnknownDogBanner> {
  bool _dismissed = false;
  int? _lastDismissedArucoId;

  @override
  Widget build(BuildContext context) {
    final unknownDog = ref.watch(unknownDogProvider);

    if (unknownDog == null || _dismissed && unknownDog.arucoId == _lastDismissedArucoId) {
      return const SizedBox.shrink();
    }

    // Reset dismissed state if a different dog appears
    if (unknownDog.arucoId != _lastDismissedArucoId) {
      _dismissed = false;
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: AppTheme.warning.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            context.push('/dogs/add?arucoId=${unknownDog.arucoId}');
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, color: Colors.black87, size: 16),
                const SizedBox(width: 6),
                Text(
                  'New dog #${unknownDog.arucoId}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _dismissed = true;
                      _lastDismissedArucoId = unknownDog.arucoId;
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.black54, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mode buttons + Drive button row (replaces video overlay dropdown)
class _ModeAndDriveRow extends ConsumerWidget {
  const _ModeAndDriveRow();

  static const _portraitModes = [RobotMode.idle, RobotMode.silentGuardian, RobotMode.coach];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(modeStateProvider);
    final displayMode = modeState.currentMode;
    final isChanging = modeState.isSwitching;
    final isLocked = modeState.isModeLocked;
    final unreadCount = ref.watch(unreadEventCountProvider);

    // Show error snackbar when mode change fails
    ref.listen<String?>(modeErrorProvider, (previous, error) {
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(modeStateProvider.notifier).clearError();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    return Row(
      children: [
        // Mode buttons (segmented style)
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: _portraitModes.map((mode) {
                final isSelected = displayMode == mode;
                final isPending = isChanging && modeState.pendingMode == mode;
                final color = _getModeColor(mode);
                final showBadge = mode == RobotMode.silentGuardian && unreadCount > 0;

                // When in a non-idle mode, Idle button shows as red "EXIT"
                final isExitButton = mode == RobotMode.idle && displayMode != RobotMode.idle;
                final buttonColor = isExitButton
                    ? Colors.red
                    : (isSelected ? color : Colors.transparent);
                final buttonLabel = isExitButton ? 'EXIT' : _getModeShortLabel(mode);
                final buttonIcon = isExitButton ? Icons.stop_circle : _getModeIcon(mode);

                return Expanded(
                  child: GestureDetector(
                    onTap: isLocked
                        ? null
                        : () {
                            ref.read(modeStateProvider.notifier).setMode(mode, source: 'dropdown');
                            if (mode == RobotMode.coach) {
                              context.push('/coach');
                            }
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isExitButton
                            ? buttonColor.withOpacity(0.85)
                            : (isSelected ? buttonColor.withOpacity(0.9) : buttonColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isPending)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              else if (isLocked && isSelected)
                                Icon(Icons.lock, size: 14, color: isSelected ? Colors.white70 : Colors.white38)
                              else
                                Icon(
                                  buttonIcon,
                                  size: 16,
                                  color: (isSelected || isExitButton) ? Colors.white : Colors.white54,
                                ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  buttonLabel,
                                  style: TextStyle(
                                    color: (isSelected || isExitButton) ? Colors.white : Colors.white54,
                                    fontWeight: (isSelected || isExitButton) ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // Event count badge for guardian
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Drive button (compact)
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/drive'),
            icon: const Icon(Icons.gamepad, size: 18),
            label: const Text('DRIVE',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _getModeShortLabel(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle: return 'Idle';
      case RobotMode.silentGuardian: return 'Guard';
      case RobotMode.coach: return 'Coach';
      default: return mode.label;
    }
  }

  static Color _getModeColor(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle: return Colors.grey;
      case RobotMode.manual: return Colors.blue;
      case RobotMode.silentGuardian: return Colors.purple;
      case RobotMode.coach: return Colors.orange;
      case RobotMode.mission: return Colors.green;
    }
  }

  static IconData _getModeIcon(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle: return Icons.pause_circle_outline;
      case RobotMode.manual: return Icons.gamepad;
      case RobotMode.silentGuardian: return Icons.visibility;
      case RobotMode.coach: return Icons.school;
      case RobotMode.mission: return Icons.flag;
    }
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
                  subtitle: dog.breed != null && dog.breed!.isNotEmpty
                      ? Text(dog.breed!)
                      : dog.color != DogColor.mixed
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
