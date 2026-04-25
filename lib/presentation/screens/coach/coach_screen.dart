import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/telemetry.dart';
import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
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

    // Build 38: NO commands in lifecycle handlers. Commands ONLY on explicit user tap.
    // If user navigates away while coaching, coach mode stays active on robot.
    // User must explicitly tap Stop to end coaching.
    return Scaffold(
        backgroundColor: Colors.black,
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
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        // Build 38: Just navigate. No commands on back button.
                        // Coach mode stays active on robot until user explicitly stops.
                        context.pop();
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: coachState.isActive
                            ? Colors.green.withOpacity(0.8)
                            : Colors.grey.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            coachState.isActive ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            coachState.isActive ? 'COACHING' : 'STOPPED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (coachState.isActive)
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: () {
                          ref.read(coachProvider.notifier).stopCoaching();
                        },
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
                      Colors.black.withOpacity(0.85),
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pets, color: AppTheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                // Priority: detection event dog name > coach state > fallback
                                // Do NOT use selectedDog.name — that locks to profile selection
                                coachState.dogName ?? 'Dog Detected',
                                style: const TextStyle(
                                  color: Colors.white,
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
                                  color: AppTheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cookie, color: AppTheme.primary, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${coachState.rewardsGiven}',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'When dog visible:',
                            style: TextStyle(
                              color: Colors.white70,
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
                                isActive: coachState.isActive,
                                onTap: coachState.isActive && isConnected
                                    ? () => ref.read(coachProvider.notifier).forceTrick(behavior)
                                    : null,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Start/Stop button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isConnected
                            ? () {
                                if (coachState.isActive) {
                                  ref.read(coachProvider.notifier).stopCoaching();
                                } else {
                                  ref.read(coachProvider.notifier).startCoaching();
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coachState.isActive
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(coachState.isActive ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          coachState.isActive ? 'Stop Coaching' : 'Start Coaching',
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
class _DogChip extends StatelessWidget {
  final Detection detection;
  const _DogChip({required this.detection});

  static const _palette = <Color>[
    Color(0xFF00E5FF),
    Color(0xFFFFC400),
    Color(0xFFFF4081),
    Color(0xFF76FF03),
    Color(0xFFB388FF),
    Color(0xFFFF6E40),
  ];

  Color get _dogColor => _palette[detection.trackKey.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final dogLabel = detection.displayName;
    final behaviorLabel = AppTheme.getBehaviorDisplayName(detection.behavior).toUpperCase();
    final confidence = detection.confidence;
    final color = detection.dogId != null
        ? _dogColor
        : AppTheme.getBehaviorColor(detection.behavior);
    return Container(
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
          if (dogLabel.isNotEmpty) ...[
            Text(
              dogLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '|',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            behaviorLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(width: 6),
            Text(
              '${(confidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable trick chip - Build 38: sends force_trick command
class _TrickChip extends StatelessWidget {
  final String behavior;
  final bool isHighlighted;
  final bool isActive;
  final VoidCallback? onTap;

  const _TrickChip({
    required this.behavior,
    required this.isHighlighted,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              ? Colors.green.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted
                ? Colors.green
                : onTap != null
                    ? AppTheme.primary.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
            width: onTap != null ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null) ...[
              Icon(
                Icons.touch_app,
                color: AppTheme.primary,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              AppTheme.getBehaviorDisplayName(behavior).toUpperCase(),
              style: TextStyle(
                color: isHighlighted ? Colors.green : Colors.white,
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
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              behavior != null ? '${AppTheme.getBehaviorDisplayName(behavior!).toUpperCase()}!' : 'GOOD!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.cookie, color: Colors.amber, size: 24),
          ],
        ),
      ),
    );
  }
}
