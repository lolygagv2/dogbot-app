import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/guardian_events_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../l10n/l10n.dart';
import '../../widgets/video/smart_video_view.dart';
import '../../widgets/video/audio_mute_toggle.dart';
import '../../widgets/status/battery_indicator.dart';
import '../../widgets/status/connection_badge.dart';
import '../../widgets/status/treat_counter_indicator.dart';
import '../../widgets/controls/ask_wimz.dart';
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
    // Build 112: in local AP mode the saved relay device id (e.g. wimz_robot_02)
    // is stale and MUST NOT be shown — it can name a DIFFERENT robot than the
    // one we're physically connected to. Show a neutral local label instead.
    final isLocal = ref.watch(isLocalModeProvider);
    final displayName = isLocal ? context.l10n.homeLocalRobot : deviceId;
    // Build 132: "paired" = a robot was actually selected/saved, NOT
    // deviceId != defaultDeviceId — the placeholder equals a real robot's id
    // (wimz_robot_01), so that comparison misread it as "no robot".
    final hasPairedDevice = isLocal || ref.watch(hasSelectedDeviceProvider);
    final w = context.wimz;

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
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: w.inkMuted,
                ),
              )
            else
              GestureDetector(
                onTap: () => context.push('/device-pairing'),
                child: Text(
                  context.l10n.homeFindYourRobot,
                  style: TextStyle(
                    fontSize: 12,
                    // A link → signal.
                    color: w.signal,
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
                  color: w.brandInk,
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: _ModeRow(),
              ),
              // AI voice status / last exchange (collapsed when idle)
              const AskWimzBanner(),

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

    final w = context.wimz;
    final color = WimzStatus.behavior(context, widget.behavior, onVideo: true);
    // The chip is filled with the behaviour colour (ink / ink-muted / error),
    // so its text takes the surface colour for contrast in both themes.
    final onChip = w.surface;
    final confidenceText =
        widget.confidence != null ? '${(widget.confidence! * 100).toInt()}%' : '';

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: onChip, size: 16),
            const SizedBox(width: 6),
            Text(
              behaviorDisplayName(context.l10n, widget.behavior).toUpperCase(),
              style: TextStyle(
                color: onChip,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (confidenceText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                confidenceText,
                style: TextStyle(
                  color: onChip.withValues(alpha: 0.7),
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

    final w = context.wimz;
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        // Card over video: raised surface, ink text (no warning wash).
        color: w.surfaceRaised.withValues(alpha: 0.95),
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
                Icon(Icons.pets, color: w.ink, size: 16),
                const SizedBox(width: 6),
                Text(
                  context.l10n.homeNewDog(unknownDog.arucoId ?? 0),
                  style: TextStyle(
                    color: w.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.add,
                  style: TextStyle(
                    // A link → signal.
                    color: w.signal,
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
                  child: Icon(Icons.close, color: w.inkMuted, size: 14),
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
/// Home mode bar (Build 178): `[ Mode: Idle ▾ ] [ EXIT ] [ AI ]`.
///
/// Replaces the three fixed segments + DRIVE that overflowed on large
/// phones. The chip opens a bottom sheet titled MODE listing Idle, Silent
/// Guardian, Coach, Mission and Manual; picking one loads it. While any
/// non-idle mode is active a red EXIT appears beside the chip and returns
/// to Idle (the default) — same semantics as the old red Idle segment.
/// Drive is reached via Manual (the drive screen enters manual mode itself).
class _ModeRow extends ConsumerWidget {
  const _ModeRow();

  static const _modes = [
    RobotMode.idle,
    RobotMode.silentGuardian,
    RobotMode.coach,
    RobotMode.mission,
    RobotMode.manual,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(modeStateProvider);
    final displayMode = modeState.currentMode;
    final isChanging = modeState.isSwitching;
    final isLocked = modeState.isModeLocked;
    final unreadCount = ref.watch(unreadEventCountProvider);
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    // Show error snackbar when mode change fails
    ref.listen<String?>(modeErrorProvider, (previous, error) {
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onError, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(error, style: TextStyle(color: cs.onError))),
              ],
            ),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: l.homeDismiss,
              textColor: cs.onError,
              onPressed: () {
                ref.read(modeStateProvider.notifier).clearError();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    final shownMode = isChanging ? (modeState.pendingMode ?? displayMode) : displayMode;
    final color = _getModeColor(context, shownMode);
    final showExit = displayMode != RobotMode.idle || (isChanging && shownMode != RobotMode.idle);
    final showBadge = displayMode == RobotMode.silentGuardian && unreadCount > 0;

    return Row(
      children: [
        // Mode chip — "Mode: Idle ▾"
        Expanded(
          child: Material(
            color: w.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openModeSheet(context, ref),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: shownMode == RobotMode.idle
                        ? w.line
                        : color.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    if (isChanging)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                      )
                    else if (isLocked)
                      Icon(Icons.lock, size: 16, color: color)
                    else
                      Icon(_getModeIcon(shownMode), size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.homeModeChip(shownMode.localizedLabel(l)),
                        style: TextStyle(
                          color: shownMode == RobotMode.idle ? w.inkMuted : w.ink,
                          fontWeight: shownMode == RobotMode.idle ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showBadge) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          // Unread count: emphasis, not an error.
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(Icons.arrow_drop_down, color: w.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        // EXIT — only while a non-idle mode is active. Returns to Idle.
        if (showExit) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: isLocked
                  ? null
                  : () => ref
                      .read(modeStateProvider.notifier)
                      .setMode(RobotMode.idle, source: 'dropdown'),
              icon: const Icon(Icons.stop_circle, size: 18),
              label: Text(
                l.homeExit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              // Stop / leave the active mode: the error slot (destructive),
              // always with the stop icon + EXIT label.
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                disabledBackgroundColor: cs.error.withValues(alpha: 0.4),
                disabledForegroundColor: cs.onError.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        // "AI": hold to speak a command to WIM-Z; the robot answers back
        // (relay voice agent). Lives here so it's reachable in EVERY mode —
        // the quick-actions Talk button below is the 5-s sound bite for the
        // dog and disappears in Silent Guardian.
        HoldToTalkButton(size: 42, label: l.homeAiShort),
      ],
    );
  }

  /// Bottom sheet: non-clickable MODE title + one row per mode.
  Future<void> _openModeSheet(BuildContext context, WidgetRef ref) async {
    final modeState = ref.read(modeStateProvider);
    final picked = await showModalBottomSheet<RobotMode>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l = ctx.l10n;
        final current = modeState.currentMode;
        final w = ctx.wimz;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      l.homeModeSheetTitle,
                      style: TextStyle(
                        color: w.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              for (final mode in _modes)
                ListTile(
                  leading: Icon(_getModeIcon(mode), color: _getModeColor(ctx, mode)),
                  title: Text(
                    mode.localizedLabel(l),
                    style: TextStyle(
                      fontWeight: mode == current ? FontWeight.bold : FontWeight.normal,
                      color: w.ink,
                    ),
                  ),
                  trailing: mode == current
                      ? Icon(Icons.check, color: _getModeColor(ctx, mode))
                      : null,
                  selected: mode == current,
                  selectedTileColor: w.surfaceSunken,
                  onTap: () => Navigator.pop(ctx, mode),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    _select(context, ref, picked);
  }

  void _select(BuildContext context, WidgetRef ref, RobotMode mode) {
    final notifier = ref.read(modeStateProvider.notifier);
    switch (mode) {
      case RobotMode.manual:
        // The drive screen enters manual mode itself and restores the
        // previous portrait mode on exit (Build 146) — don't double-send.
        context.push('/drive');
        return;
      case RobotMode.mission:
        // Missions are started per-mission from the Missions screen
        // (start_mission); the robot enters mission mode from there.
        context.go('/missions');
        return;
      case RobotMode.coach:
        notifier.setMode(mode, source: 'dropdown');
        context.push('/coach');
        return;
      case RobotMode.idle:
      case RobotMode.silentGuardian:
        notifier.setMode(mode, source: 'dropdown');
        return;
    }
  }

  /// Idle is muted; every active mode is ink. The mode icon + label always
  /// sit beside the colour.
  static Color _getModeColor(BuildContext context, RobotMode mode) {
    final w = context.wimz;
    switch (mode) {
      case RobotMode.idle:
        return w.inkMuted;
      case RobotMode.manual:
      case RobotMode.silentGuardian:
      case RobotMode.coach:
      case RobotMode.mission:
        return w.ink;
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
                  color: context.wimz.inkMuted,
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
                  Text(
                    context.l10n.homeSelectDog,
                    style: const TextStyle(
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
                    label: Text(context.l10n.add),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...dogs.map((dog) => ListTile(
                  leading: _DogAvatar(profile: dog, size: 44),
                  title: Text(dog.name),
                  subtitle: dog.isPlaceholder
                      ? Text(context.l10n.dogNameYourDog,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary))
                      : dog.breed != null && dog.breed!.isNotEmpty
                          ? Text(dog.breed!)
                          : dog.color != DogColor.mixed
                              ? Text(dog.color.localizedLabel(context.l10n))
                              : null,
                  trailing: current?.id == dog.id
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: w.surfaceRaised,
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: profile == null
          ? Icon(Icons.add, color: cs.primary, size: size * 0.5)
          : _buildPhoto(context),
    );
  }

  Widget _buildPhoto(BuildContext context) {
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
            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
          ),
        );
      }
    }
    if (profile!.photoUrl != null) {
      return ClipOval(
        child: Image.network(
          profile!.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
        ),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Text(
        profile!.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
