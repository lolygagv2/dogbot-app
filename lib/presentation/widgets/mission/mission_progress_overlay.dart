import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/mission.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Mission progress overlay for video stream (Build 31)
/// Shows real-time mission status, stage progress, and circular pie during watching
class MissionProgressOverlay extends ConsumerWidget {
  const MissionProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);

    // Only show when there's an active mission with progress
    if (!missionsState.hasActiveMission || missionsState.currentProgress == null) {
      return const SizedBox.shrink();
    }

    final progress = missionsState.currentProgress!;
    final status = progress.statusEnum;

    // Don't show overlay if status is unknown/stopped
    if (!status.isActive && status != MissionStatus.completed && status != MissionStatus.success) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: _MissionOverlayCard(
            progress: progress,
            status: status,
          ),
        ),
      ),
    );
  }
}

class _MissionOverlayCard extends StatelessWidget {
  final MissionProgress progress;
  final MissionStatus status;

  const _MissionOverlayCard({
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final muted = w.onVideo.withValues(alpha: 0.7);
    // Build 34: Reduced overlay size by ~40% for less intrusive display
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: w.scrim(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(context).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage indicator
          if (progress.localizedStage(context.l10n) != null)
            Text(
              progress.localizedStage(context.l10n)!,
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 8),

          // Main content - icon/progress + status
          _buildMainContent(context),

          const SizedBox(height: 8),

          // Dog name and rewards (compact)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (progress.dogName != null) ...[
                Icon(Icons.pets, size: 10, color: muted),
                const SizedBox(width: 2),
                Text(
                  progress.dogName!,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.cookie, size: 10, color: w.onVideo),
              const SizedBox(width: 2),
              Text(
                '${progress.rewardsGiven}',
                style: TextStyle(
                  color: w.onVideo,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildMainContent(BuildContext context) {
    final statusLabel = progress.localizedStatus(context.l10n);
    if (status == MissionStatus.watching) {
      // Show circular progress during watching
      return _CircularPieProgress(
        progress: progress.effectiveProgress,
        color: _getStatusColor(context),
        label: statusLabel,
      );
    }

    if (status == MissionStatus.success || status == MissionStatus.completed) {
      // Success animation
      return _SuccessIndicator(
        label: statusLabel,
      );
    }

    if (status == MissionStatus.failed) {
      // Failure indicator
      return _FailureIndicator(
        label: statusLabel,
      );
    }

    // Default: pulsing status with icon
    return _StatusIndicator(
      status: status,
      label: statusLabel,
      trick: progress.trick == null ? null : behaviorDisplayName(context.l10n, progress.trick),
    );
  }

  /// Overlay sits on video (always dark), so status is white / muted white,
  /// with error only for a failed attempt. Every state also shows its icon
  /// (or the pie) and the status label.
  Color _getStatusColor(BuildContext context) {
    final w = context.wimz;
    switch (status) {
      case MissionStatus.waitingForDog:
        return w.onVideo.withValues(alpha: 0.7);
      case MissionStatus.greeting:
        return w.onVideo;
      case MissionStatus.command:
        return w.onVideo;
      case MissionStatus.watching:
        return w.onVideo;
      case MissionStatus.success:
      case MissionStatus.completed:
        return w.onVideo;
      case MissionStatus.failed:
        return Theme.of(context).colorScheme.error;
      case MissionStatus.retry:
        return w.onVideo.withValues(alpha: 0.7);
      default:
        return w.onVideo.withValues(alpha: 0.7);
    }
  }
}

/// Circular pie progress indicator (Build 34: reduced size)
class _CircularPieProgress extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;

  const _CircularPieProgress({
    required this.progress,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              CustomPaint(
                size: const Size(50, 50),
                painter: _PieProgressPainter(
                  progress: progress,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
              ),
              // Percentage text
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PieProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _PieProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc (pie style)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PieProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Success indicator with checkmark animation (Build 34: reduced size)
class _SuccessIndicator extends StatelessWidget {
  final String label;

  const _SuccessIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: w.onVideo.withValues(alpha: 0.2),
            border: Border.all(color: w.onVideo, width: 2),
          ),
          child: Icon(
            Icons.check,
            color: w.onVideo,
            size: 24,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 600.ms),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: w.onVideo,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Failure indicator with X (Build 34: reduced size)
class _FailureIndicator extends StatelessWidget {
  final String label;

  const _FailureIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    // Failed attempt: error tint with the X icon and the status label.
    final error = Theme.of(context).colorScheme.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error.withValues(alpha: 0.2),
            border: Border.all(color: error, width: 2),
          ),
          child: Icon(
            Icons.close,
            color: error,
            size: 24,
          ),
        ).animate().shake(duration: 500.ms),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: error,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Generic status indicator with pulsing animation (Build 34: reduced size)
class _StatusIndicator extends StatelessWidget {
  final MissionStatus status;
  final String label;
  final String? trick;

  const _StatusIndicator({
    required this.status,
    required this.label,
    this.trick,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            _getStatusIcon(),
            color: color,
            size: 20,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// On video: white for the active prompts, muted white while waiting.
  /// Each state has its own icon ([_getStatusIcon]) and the label.
  Color _getStatusColor(BuildContext context) {
    final w = context.wimz;
    switch (status) {
      case MissionStatus.waitingForDog:
        return w.onVideo.withValues(alpha: 0.7);
      case MissionStatus.greeting:
        return w.onVideo;
      case MissionStatus.command:
        return w.onVideo;
      case MissionStatus.retry:
        return w.onVideo.withValues(alpha: 0.7);
      default:
        return w.onVideo.withValues(alpha: 0.7);
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MissionStatus.waitingForDog:
        return Icons.pets;
      case MissionStatus.greeting:
        return Icons.campaign;
      case MissionStatus.command:
        return Icons.record_voice_over;
      case MissionStatus.retry:
        return Icons.refresh;
      default:
        return Icons.hourglass_empty;
    }
  }
}
