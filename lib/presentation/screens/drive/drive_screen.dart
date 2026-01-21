import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/video/webrtc_video_view.dart';
import '../../widgets/controls/pan_tilt_control.dart';
import '../../theme/app_theme.dart';

class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final telemetry = ref.watch(telemetryProvider);
    final motorControl = ref.watch(motorControlProvider.notifier);
    final motorState = ref.watch(motorControlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive'),
        actions: [
          IconButton(
            onPressed: () => motorControl.emergencyStop(),
            icon: const Icon(Icons.emergency, color: Colors.red),
            tooltip: 'Emergency Stop',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              // Use WebRTC for video streaming via relay
              child: const WebRTCVideoView(),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('DRIVE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        Joystick(
                          mode: JoystickMode.all,
                          period: AppConstants.joystickSendInterval,
                          listener: (details) {
                            motorControl.setFromJoystick(details.x, -details.y);
                          },
                          onStickDragEnd: () => motorControl.stop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SpeedIndicator(label: 'L', value: motorState.left),
                        const SizedBox(height: 16),
                        _SpeedIndicator(label: 'R', value: motorState.right),
                        const SizedBox(height: 24),
                        if (telemetry.dogDetected)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.getBehaviorColor(telemetry.currentBehavior),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.pets, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('CAMERA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        const PanTiltControl(),
                      ],
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

class _SpeedIndicator extends StatelessWidget {
  final String label;
  final double value;

  const _SpeedIndicator({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0 ? Colors.green : (value < 0 ? Colors.red : Colors.grey);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: value > 0 ? 30 : null,
                top: value < 0 ? 30 : null,
                child: Container(
                  width: 36,
                  height: (value.abs() * 28).clamp(0.0, 28.0),
                  color: color.withOpacity(0.7),
                ),
              ),
              Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}
