import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Battery chip: icon + percentage always; colour via [WimzStatus.battery]
/// (ink / gold-deep when low / error when critical).
class BatteryIndicator extends StatelessWidget {
  final double level;

  const BatteryIndicator({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = WimzStatus.battery(context, level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getBatteryIcon(), color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          '${level.toInt()}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 12),
        ),
      ],
    );
  }

  IconData _getBatteryIcon() {
    if (level > 90) return Icons.battery_full;
    if (level > 70) return Icons.battery_6_bar;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 30) return Icons.battery_3_bar;
    if (level > 15) return Icons.battery_2_bar;
    if (level > 5) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }
}
