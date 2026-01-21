import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/providers/control_provider.dart';

class PanTiltControl extends ConsumerWidget {
  const PanTiltControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servoControl = ref.watch(servoControlProvider.notifier);
    final servoState = ref.watch(servoControlProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Joystick(
          mode: JoystickMode.all,
          period: AppConstants.joystickSendInterval,
          base: JoystickBase(
            size: AppConstants.panTiltControlSize,
            decoration: JoystickBaseDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              drawOuterCircle: false,
            ),
          ),
          stick: JoystickStick(
            size: 40,
            decoration: JoystickStickDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          listener: (details) {
            // Negate pan so joystick left = camera left
            final pan = -details.x * AppConstants.maxPanAngle;
            final tilt = -details.y * AppConstants.maxTiltAngle;
            servoControl.setPosition(pan, tilt);
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'P:${servoState.pan.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
            const SizedBox(width: 8),
            Text(
              'T:${servoState.tilt.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => servoControl.center(),
          icon: const Icon(Icons.center_focus_strong, size: 16),
          label: const Text('Center'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
