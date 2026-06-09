import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../theme/app_theme.dart';

class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    // Build 132: "paired" = a robot was actually selected/saved, NOT
    // deviceId != defaultDeviceId — the placeholder equals a real robot's id
    // (wimz_robot_01), so that comparison showed "No Robot" for that robot.
    // Local mode is always "paired" (direct connection, no relay id needed).
    final isLocal = ref.watch(isLocalModeProvider);
    final hasPairedDevice = isLocal || ref.watch(hasSelectedDeviceProvider);

    // Determine color and text based on 3-tier status
    Color color;
    String text;
    IconData? icon;

    // Build 104: when no device is paired yet, don't show "Connecting…" —
    // there's nothing to connect to. Show "No Robot" so the user knows the
    // next step is pairing, not waiting.
    if (!hasPairedDevice && !connection.isDemoMode) {
      return _PillContainer(
        color: AppTheme.disconnected,
        icon: Icons.device_unknown,
        text: 'No Robot',
      );
    }

    switch (connection.status) {
      case ConnectionStatus.disconnected:
        color = AppTheme.disconnected;
        text = 'Offline';
        icon = Icons.cloud_off;
        break;
      case ConnectionStatus.connecting:
        color = AppTheme.connecting;
        text = 'Connecting...';
        icon = Icons.cloud_sync;
        break;
      case ConnectionStatus.relayConnected:
        color = connection.isNotPaired ? AppTheme.warning : AppTheme.connecting;
        text = connection.isNotPaired ? 'Not Paired' : 'Waiting...';
        icon = Icons.cloud_done;
        break;
      case ConnectionStatus.robotOnline:
        color = AppTheme.connected;
        text = 'Robot Online';
        icon = Icons.smart_toy;
        break;
      case ConnectionStatus.error:
        color = AppTheme.error;
        text = 'Error';
        icon = Icons.error_outline;
        break;
      case ConnectionStatus.superseded:
        // B1: another device took over this account/device pair.
        color = AppTheme.warning;
        text = 'Other Device Active';
        icon = Icons.swap_horiz;
        break;
    }

    // Demo mode override
    if (connection.isDemoMode) {
      color = AppTheme.secondary;
      text = 'Demo';
      icon = Icons.play_circle_outline;
    }

    return _PillContainer(
      color: color,
      icon: icon,
      text: text,
      glow: connection.status == ConnectionStatus.robotOnline,
    );
  }
}

class _PillContainer extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String text;
  final bool glow;

  const _PillContainer({
    required this.color,
    required this.icon,
    required this.text,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
