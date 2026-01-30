import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/mission.dart';
import '../../../domain/providers/missions_provider.dart';
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
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage indicator
          if (progress.stageDisplay != null)
            Text(
              progress.stageDisplay!,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 12),

          // Main content - icon/progress + status
          _buildMainContent(),

          const SizedBox(height: 12),

          // Dog name and rewards
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (progress.dogName != null) ...[
                const Icon(Icons.pets, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  progress.dogName!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.cookie, size: 14, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text(
                '${progress.rewardsGiven}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildMainContent() {
    if (status == MissionStatus.watching) {
      // Show circular progress during watching
      return _CircularPieProgress(
        progress: progress.effectiveProgress,
        color: _getStatusColor(),
        label: progress.statusDisplay,
      );
    }

    if (status == MissionStatus.success || status == MissionStatus.completed) {
      // Success animation
      return _SuccessIndicator(
        label: progress.statusDisplay,
      );
    }

    if (status == MissionStatus.failed) {
      // Failure indicator
      return _FailureIndicator(
        label: progress.statusDisplay,
      );
    }

    // Default: pulsing status with icon
    return _StatusIndicator(
      status: status,
      label: progress.statusDisplay,
      trick: progress.trick,
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case MissionStatus.waitingForDog:
        return Colors.orange;
      case MissionStatus.greeting:
        return AppTheme.primary;
      case MissionStatus.command:
        return Colors.amber;
      case MissionStatus.watching:
        return AppTheme.primary;
      case MissionStatus.success:
      case MissionStatus.completed:
        return Colors.green;
      case MissionStatus.failed:
        return Colors.red;
      case MissionStatus.retry:
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }
}

/// Circular pie progress indicator
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
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              CustomPaint(
                size: const Size(80, 80),
                painter: _PieProgressPainter(
                  progress: progress,
                  color: color,
                  backgroundColor: color.withOpacity(0.2),
                ),
              ),
              // Percentage text
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
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

/// Success indicator with checkmark animation
class _SuccessIndicator extends StatelessWidget {
  final String label;

  const _SuccessIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.2),
            border: Border.all(color: Colors.green, width: 3),
          ),
          child: const Icon(
            Icons.check,
            color: Colors.green,
            size: 36,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 600.ms),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Failure indicator with X
class _FailureIndicator extends StatelessWidget {
  final String label;

  const _FailureIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.2),
            border: Border.all(color: Colors.red, width: 3),
          ),
          child: const Icon(
            Icons.close,
            color: Colors.red,
            size: 36,
          ),
        ).animate().shake(duration: 500.ms),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Generic status indicator with pulsing animation
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor().withOpacity(0.2),
            border: Border.all(color: _getStatusColor(), width: 2),
          ),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 32,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _getStatusColor(),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case MissionStatus.waitingForDog:
        return Colors.orange;
      case MissionStatus.greeting:
        return AppTheme.primary;
      case MissionStatus.command:
        return Colors.amber;
      case MissionStatus.retry:
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
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
