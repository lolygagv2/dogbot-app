import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/telemetry.dart';
import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video/smart_video_view.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  @override
  void initState() {
    super.initState();
    // Start coaching when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCoaching();
    });
  }

  void _startCoaching() {
    final isConnected = ref.read(isRobotOnlineProvider);
    if (isConnected) {
      ref.read(coachProvider.notifier).startCoaching();
    }
  }

  @override
  void dispose() {
    // Stop coaching when leaving screen (but don't call provider methods)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coachState = ref.watch(coachProvider);
    // selectedDog is no longer used here for the chip — see C5 — but kept
    // for backward compatibility with other widgets that might watch it.
    // ignore: unused_local_variable
    final selectedDog = ref.watch(selectedDogProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);
    // Everything here sits over live video (always a dark ground), so the
    // on-video tokens are used throughout rather than ink / surface.
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    // Build 38: NO commands in lifecycle handlers. Commands ONLY on explicit user tap.
    // If user navigates away while coaching, coach mode stays active on robot.
    // User must explicitly tap Stop to end coaching.
    return Scaffold(
        backgroundColor: w.brandInk,
        body: Stack(
          children: [
            // Full screen video — WebRTC first, MJPEG fallback in local mode
            const Positioned.fill(
              child: SmartVideoView(),
            ),

            // C5: One detection chip per visible dog. Robot's C0 fix
            // guarantees one track per physical dog, so this no longer
            // double-renders ("Dog" + "Elsa" on the same animal).
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Builder(
                  builder: (context) {
                    final detections = ref.watch(allDetectionsProvider);
                    if (detections.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in detections.values)
                          _DogChip(detection: d),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Top bar with back and stop buttons
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      w.scrim(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: w.onVideo),
                      onPressed: () {
                        // Build 93: Leaving the coach screen by any means exits
                        // coach mode. stopCoaching() routes through set_mode(idle),
                        // the only working teardown path on the cloud-relay route.
                        ref.read(coachProvider.notifier).stopCoaching();
                        context.pop();
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      // Live status chip: signal while coaching, muted when
                      // (on-video tokens: the coach view sits on the camera feed)
                      // stopped; the eye icon + word carry the state.
                      decoration: BoxDecoration(
                        color: coachState.isActive ? WimzColors.dark.signal : w.inkMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            coachState.isActive ? Icons.visibility : Icons.visibility_off,
                            color: coachState.isActive ? WimzColors.dark.inkOnSignal : w.surface,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            coachState.isActive ? context.l10n.coachCoachingBadge : context.l10n.coachStoppedBadge,
                            style: TextStyle(
                              color: coachState.isActive ? WimzColors.dark.inkOnSignal : w.surface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Coach info overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      w.scrim(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reward flash
                    if (coachState.hasRecentReward)
                      _RewardFlash(behavior: coachState.lastRewardBehavior),

                    const SizedBox(height: 12),

                    // Coach info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: w.onVideo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: w.lineOnVideo,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pets, color: w.onVideo, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                // Priority: detection event dog name > coach state > fallback
                                // Do NOT use selectedDog.name — that locks to profile selection
                                coachState.dogName ?? context.l10n.coachDogDetected,
                                style: TextStyle(
                                  color: w.onVideo,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: w.onVideo.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cookie, color: w.onVideo, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${coachState.rewardsGiven}',
                                      style: TextStyle(
                                        color: w.onVideo,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.coachWhenDogVisible,
                            style: TextStyle(
                              color: w.onVideo.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: coachState.watchingFor.map((behavior) {
                              final isHighlighted = coachState.lastRewardBehavior?.toLowerCase() == behavior.toLowerCase();
                              return _TrickChip(
                                behavior: behavior,
                                isHighlighted: isHighlighted,
                                isActiveTrick: coachState.isActiveTrick(behavior),
                                isActive: coachState.isActive,
                                onTap: coachState.isActive && isConnected
                                    ? () {
                                        final ok = ref
                                            .read(coachProvider.notifier)
                                            .forceTrick(behavior);
                                        if (!ok && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                              context.l10n.coachSelectDogHint,
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ));
                                        }
                                      }
                                    : null,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Build 93: Unified Exit button — replaces "Stop Coaching".
                    // Calls stopCoaching() (which routes through set_mode(idle))
                    // and pops back to home. Same teardown path as the home-screen
                    // EXIT button. If coach somehow isn't active, falls back to
                    // a plain pop.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isConnected
                            ? () {
                                if (coachState.isActive) {
                                  ref.read(coachProvider.notifier).stopCoaching();
                                }
                                context.pop();
                              }
                            : null,
                        // Stop / leave coach mode: the error slot (destructive),
                        // with the stop icon + EXIT label.
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle),
                        label: Text(
                          context.l10n.coachExit,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// C5: Per-dog chip showing dog name, behavior, and confidence. Color is
/// hashed from dog_id (or aruco id) so the same dog renders consistently.
/// The palette is the brand differentiation set (ink / ink-muted / signal /
/// line-strong / error, on-video tokens, no gold); the chip prints the dog's
/// name, so colour never identifies a dog alone.
class _DogChip extends StatelessWidget {
  final Detection detection;
  const _DogChip({required this.detection});

  static List<Color> _palette(BuildContext context) =>
      WimzStatus.dogPalette(context, onVideo: true);

  Color _dogColor(BuildContext context) {
    final palette = _palette(context);
    return palette[detection.trackKey.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final dogLabel = detection.localizedDisplayName(context.l10n);
    final behaviorLabel = behaviorDisplayName(context.l10n, detection.behavior).toUpperCase();
    final confidence = detection.confidence;
    final color = detection.dogId != null
        ? _dogColor(context)
        : WimzStatus.behavior(context, detection.behavior, onVideo: true);
    // Text takes the surface colour so it contrasts with whichever brand
    // colour fills the chip in either theme.
    final onChip = w.surface;
    return Container(
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
          if (dogLabel.isNotEmpty) ...[
            Text(
              dogLabel,
              style: TextStyle(
                color: onChip,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '|',
              style: TextStyle(color: onChip.withValues(alpha: 0.54), fontSize: 12),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            behaviorLabel,
            style: TextStyle(
              color: onChip,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(width: 6),
            Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                color: onChip.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable trick chip - Build 38: sends force_trick command.
/// Reward flash (solid on-video, 3s) wins over the active-trick highlight
/// (signal = the trick the robot is live-coaching); tapping a different
/// chip force-switches the session and moves the highlight.
class _TrickChip extends StatelessWidget {
  final String behavior;
  final bool isHighlighted;
  final bool isActiveTrick;
  final bool isActive;
  final VoidCallback? onTap;

  const _TrickChip({
    required this.behavior,
    required this.isHighlighted,
    required this.isActiveTrick,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    // Over video: on-video white for text; signal only for the live
    // (active) trick. The active trick also swaps its icon so the state is
    // not carried by colour alone.
    final accent = isHighlighted
        ? w.onVideo
        : isActiveTrick
            ? WimzColors.dark.signal
            : w.onVideo;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isHighlighted
              ? w.onVideo.withValues(alpha: 0.3)
              : isActiveTrick
                  ? WimzColors.dark.signal.withValues(alpha: 0.35)
                  : w.onVideo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted
                ? w.onVideo
                : isActiveTrick
                    ? WimzColors.dark.signal
                    : onTap != null
                        ? w.onVideo.withValues(alpha: 0.5)
                        : w.lineOnVideo,
            width: isActiveTrick || onTap != null ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null || isActiveTrick) ...[
              Icon(
                isActiveTrick ? Icons.radio_button_checked : Icons.touch_app,
                color: accent,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              behaviorDisplayName(context.l10n, behavior).toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated reward flash overlay
class _RewardFlash extends StatelessWidget {
  final String? behavior;

  const _RewardFlash({this.behavior});

  @override
  Widget build(BuildContext context) {
    // The Coach screen's ONE gold element: the reward celebration pill
    // (brand-gold fill, ink-on-gold text, flat — no glow).
    final w = context.wimz;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: w.brandGold,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, color: w.inkOnGold, size: 24),
            const SizedBox(width: 8),
            Text(
              behavior != null ? context.l10n.coachBehaviorBang(AppTheme.getBehaviorDisplayName(behavior!).toUpperCase()) : context.l10n.coachGoodBang,
              style: TextStyle(
                color: w.inkOnGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.cookie, color: w.inkOnGold, size: 24),
          ],
        ),
      ),
    );
  }
}
