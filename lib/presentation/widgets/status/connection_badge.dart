import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/connection_provider.dart';
import '../../theme/app_theme.dart';

class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);

    // Determine color and text based on 3-tier status
    Color color;
    String text;
    IconData? icon;

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
    }

    // Demo mode override
    if (connection.isDemoMode) {
      color = AppTheme.secondary;
      text = 'Demo';
      icon = Icons.play_circle_outline;
    }

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
              boxShadow: connection.status == ConnectionStatus.robotOnline
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
