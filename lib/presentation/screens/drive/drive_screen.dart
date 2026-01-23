import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/video/webrtc_video_view.dart';
import '../../widgets/controls/pan_tilt_control.dart';
import '../../widgets/controls/push_to_talk.dart';
import '../../theme/app_theme.dart';

class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);
    final motorControl = ref.watch(motorControlProvider.notifier);
    final motorState = ref.watch(motorControlProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        actions: [
          // Emergency Stop button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => motorControl.emergencyStop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emergency, color: Colors.white),
              ),
              tooltip: 'Emergency Stop',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen video background
          const WebRTCVideoView(),

          // Top status bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Speed indicators
                _CompactSpeedIndicator(
                  leftSpeed: motorState.left,
                  rightSpeed: motorState.right,
                ),
                // Detection indicator
                if (telemetry.dogDetected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.getBehaviorColor(telemetry.currentBehavior),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          telemetry.currentBehavior?.toUpperCase() ?? 'DETECTED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom controls - joysticks overlaid
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Drive joystick (left)
                _OverlayJoystick(
                  label: 'DRIVE',
                  onStickMove: (x, y) {
                    motorControl.setFromJoystick(x, -y);
                  },
                  onStickEnd: () => motorControl.stop(),
                ),

                // Center controls - treat, center, and push-to-talk
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Push-to-talk controls
                    const PushToTalkControls(compact: true),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OverlayButton(
                          icon: Icons.cookie,
                          label: 'TREAT',
                          onTap: () => ref.read(treatControlProvider).dispense(),
                        ),
                        const SizedBox(width: 12),
                        _OverlayButton(
                          icon: Icons.center_focus_strong,
                          label: 'CENTER',
                          onTap: () => ref.read(servoControlProvider.notifier).center(),
                        ),
                      ],
                    ),
                  ],
                ),

                // Camera joystick (right)
                const _OverlayCameraControl(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact speed indicator for overlay
class _CompactSpeedIndicator extends StatelessWidget {
  final double leftSpeed;
  final double rightSpeed;

  const _CompactSpeedIndicator({
    required this.leftSpeed,
    required this.rightSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpeedBar(label: 'L', value: leftSpeed),
          const SizedBox(width: 8),
          _SpeedBar(label: 'R', value: rightSpeed),
        ],
      ),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final String label;
  final double value;

  const _SpeedBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.05
        ? Colors.green
        : (value < -0.05 ? Colors.red : Colors.grey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: value >= 0 ? Alignment.centerLeft : Alignment.centerRight,
            widthFactor: value.abs().clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Semi-transparent joystick overlay
class _OverlayJoystick extends StatelessWidget {
  final String label;
  final void Function(double x, double y) onStickMove;
  final VoidCallback onStickEnd;

  const _OverlayJoystick({
    required this.label,
    required this.onStickMove,
    required this.onStickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(75),
          ),
          child: Joystick(
            mode: JoystickMode.all,
            period: AppConstants.joystickSendInterval,
            base: JoystickBase(
              size: 140,
              decoration: JoystickBaseDecoration(
                color: Colors.white.withOpacity(0.1),
                drawOuterCircle: false,
                drawInnerCircle: false,
                drawMiddleCircle: false,
              ),
            ),
            stick: JoystickStick(
              size: 50,
              decoration: JoystickStickDecoration(
                color: AppTheme.primary.withOpacity(0.8),
              ),
            ),
            listener: (details) {
              onStickMove(details.x, details.y);
            },
            onStickDragEnd: onStickEnd,
          ),
        ),
      ],
    );
  }
}

/// Camera pan/tilt control overlay
class _OverlayCameraControl extends ConsumerWidget {
  const _OverlayCameraControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servoControl = ref.watch(servoControlProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'CAMERA',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(75),
          ),
          child: Joystick(
            mode: JoystickMode.all,
            period: AppConstants.joystickSendInterval,
            base: JoystickBase(
              size: 140,
              decoration: JoystickBaseDecoration(
                color: Colors.white.withOpacity(0.1),
                drawOuterCircle: false,
                drawInnerCircle: false,
                drawMiddleCircle: false,
              ),
            ),
            stick: JoystickStick(
              size: 50,
              decoration: JoystickStickDecoration(
                color: Colors.orange.withOpacity(0.8),
              ),
            ),
            listener: (details) {
              // Convert joystick to pan/tilt angles
              final pan = details.x * AppConstants.maxPanAngle;
              final tilt = -details.y * AppConstants.maxTiltAngle;
              servoControl.setPosition(pan, tilt);
            },
            onStickDragEnd: () => servoControl.stopTracking(),
          ),
        ),
      ],
    );
  }
}

/// Overlay action button
class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
