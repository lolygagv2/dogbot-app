import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../domain/providers/control_provider.dart';
import '../../theme/app_theme.dart';

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatControl = ref.watch(treatControlProvider);
    final ledControl = ref.watch(ledControlProvider);
    final audioControl = ref.watch(audioControlProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.cookie,
          label: 'Treat',
          color: AppTheme.accent,
          onPressed: () => treatControl.dispense(),
        ),
        _ActionButton(
          icon: Icons.celebration,
          label: 'Celebrate',
          color: Colors.purple,
          onPressed: () => ledControl.setPattern(LedPatterns.celebration),
        ),
        _ActionButton(
          icon: Icons.volume_up,
          label: 'Good Dog',
          color: Colors.blue,
          onPressed: () => audioControl.play('good_dog.mp3'),
        ),
        _ActionButton(
          icon: Icons.lightbulb,
          label: 'Rainbow',
          color: Colors.orange,
          onPressed: () => ledControl.setPattern(LedPatterns.rainbow),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withOpacity(0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
