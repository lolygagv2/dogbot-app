import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';

/// Premium HUD overlay for video stream - Tesla/DJI inspired
class VideoHudOverlay extends StatelessWidget {
  final bool dogDetected;
  final String? behavior;
  final double? confidence;
  final List<double>? bbox; // [x, y, w, h] normalized 0-1
  final double battery;
  final String mode;
  final bool isRecording;
  final int fps;
  final Size videoSize;

  const VideoHudOverlay({
    super.key,
    this.dogDetected = false,
    this.behavior,
    this.confidence,
    this.bbox,
    this.battery = 0,
    this.mode = 'idle',
    this.isRecording = false,
    this.fps = 0,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Corner brackets (HUD frame)
        ..._buildCornerBrackets(),

        // Top bar - status info
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildTopBar(),
        ),

        // Bottom bar - mode and controls hint
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _buildBottomBar(),
        ),

        // Detection bounding box
        if (dogDetected && bbox != null) _buildDetectionBox(),

        // Center reticle (subtle)
        Center(child: _buildReticle()),

        // Recording indicator
        if (isRecording)
          Positioned(
            top: 12,
            right: 12,
            child: _buildRecordingIndicator(),
          ),
      ],
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 24.0;
    const thickness = 2.0;
    const color = AppTheme.primary;
    const opacity = 0.5;

    Widget bracket(bool top, bool left) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide(color: color.withOpacity(opacity), width: thickness) : BorderSide.none,
            bottom: !top ? BorderSide(color: color.withOpacity(opacity), width: thickness) : BorderSide.none,
            left: left ? BorderSide(color: color.withOpacity(opacity), width: thickness) : BorderSide.none,
            right: !left ? BorderSide(color: color.withOpacity(opacity), width: thickness) : BorderSide.none,
          ),
        ),
      );
    }

    return [
      Positioned(top: 8, left: 8, child: bracket(true, true)),
      Positioned(top: 8, right: 8, child: bracket(true, false)),
      Positioned(bottom: 8, left: 8, child: bracket(false, true)),
      Positioned(bottom: 8, right: 8, child: bracket(false, false)),
    ];
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // FPS counter
        HudLabel(
          label: 'FPS',
          value: fps.toString(),
          valueColor: fps > 10 ? AppTheme.accent : AppTheme.warning,
        ),

        // Detection status
        if (dogDetected)
          _DetectionBadge(
            behavior: behavior,
            confidence: confidence,
          ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.8, 0.8)),

        // Battery
        HudLabel(
          label: 'BAT',
          value: '${battery.toInt()}%',
          icon: Icons.battery_full,
          valueColor: AppTheme.getBatteryColor(battery),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Timestamp
        HudLabel(
          label: '',
          value: _formatTime(DateTime.now()),
          valueColor: AppTheme.textSecondary,
        ),

        // Mode
        _ModeBadge(mode: mode),

        // Coordinates placeholder
        const HudLabel(
          label: 'PAN',
          value: '0°',
          valueColor: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildDetectionBox() {
    if (bbox == null || bbox!.length < 4) return const SizedBox.shrink();

    final color = AppTheme.getBehaviorColor(behavior);
    final left = bbox![0] * videoSize.width;
    final top = bbox![1] * videoSize.height;
    final width = bbox![2] * videoSize.width;
    final height = bbox![3] * videoSize.height;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: AppTheme.glowShadow(color, blur: 10),
        ),
        child: Stack(
          children: [
            // Corner accents
            ...List.generate(4, (i) {
              final isTop = i < 2;
              final isLeft = i % 2 == 0;
              return Positioned(
                top: isTop ? 0 : null,
                bottom: !isTop ? 0 : null,
                left: isLeft ? 0 : null,
                right: !isLeft ? 0 : null,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border(
                      top: isTop ? BorderSide(color: color, width: 3) : BorderSide.none,
                      bottom: !isTop ? BorderSide(color: color, width: 3) : BorderSide.none,
                      left: isLeft ? BorderSide(color: color, width: 3) : BorderSide.none,
                      right: !isLeft ? BorderSide(color: color, width: 3) : BorderSide.none,
                    ),
                  ),
                ),
              );
            }),

            // Label
            Positioned(
              top: -20,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${behavior?.toUpperCase() ?? "DOG"} ${((confidence ?? 0) * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.background,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 2000.ms, color: color.withOpacity(0.3)),
    );
  }

  Widget _buildReticle() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _ReticlePainter(
          color: AppTheme.textTertiary.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.error,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeIn(duration: 500.ms)
            .then()
            .fadeOut(duration: 500.ms),
        const SizedBox(width: 6),
        const Text(
          'REC',
          style: TextStyle(
            color: AppTheme.error,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class _DetectionBadge extends StatelessWidget {
  final String? behavior;
  final double? confidence;

  const _DetectionBadge({this.behavior, this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getBehaviorColor(behavior);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
        boxShadow: AppTheme.glowShadow(color, blur: 15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseIndicator(color: color, size: 8),
          const SizedBox(width: 8),
          Text(
            behavior?.toUpperCase() ?? 'DETECTED',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(width: 8),
            Text(
              '${(confidence! * 100).toInt()}%',
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String mode;

  const _ModeBadge({required this.mode});

  Color get _modeColor {
    switch (mode.toLowerCase()) {
      case 'training':
        return AppTheme.accent;
      case 'guardian':
        return AppTheme.secondary;
      case 'manual':
        return AppTheme.primary;
      case 'docking':
        return AppTheme.warning;
      default:
        return AppTheme.textTertiary;
    }
  }

  IconData get _modeIcon {
    switch (mode.toLowerCase()) {
      case 'training':
        return Icons.school;
      case 'guardian':
        return Icons.shield;
      case 'manual':
        return Icons.gamepad;
      case 'docking':
        return Icons.battery_charging_full;
      default:
        return Icons.pause_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _modeColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_modeIcon, size: 14, color: _modeColor),
          const SizedBox(width: 6),
          Text(
            mode.toUpperCase(),
            style: TextStyle(
              color: _modeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;

  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Circle
    canvas.drawCircle(center, radius * 0.6, paint);

    // Cross hairs
    const gap = 8.0;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx - gap, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
