import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final l = context.l10n;
    // Build 132: "paired" = a robot was actually selected/saved, NOT
    // deviceId != defaultDeviceId — the placeholder equals a real robot's id
    // (wimz_robot_01), so that comparison showed "No Robot" for that robot.
    // Local mode is always "paired" (direct connection, no relay id needed).
    final isLocal = ref.watch(isLocalModeProvider);
    final hasPairedDevice = isLocal || ref.watch(hasSelectedDeviceProvider);
    // signal = online/live only; everything that is merely not-yet-connected
    // is ink-muted; a genuine error is colorScheme.error. Every state also
    // carries an icon and a word.
    final w = context.wimz;

    // Determine color and text based on 3-tier status
    Color color;
    String text;
    IconData? icon;

    // Build 104: when no device is paired yet, don't show "Connecting…" —
    // there's nothing to connect to. Show "No Robot" so the user knows the
    // next step is pairing, not waiting.
    if (!hasPairedDevice && !connection.isDemoMode) {
      return _PillContainer(
        color: w.inkMuted,
        icon: Icons.device_unknown,
        text: l.connBadgeNoRobot,
      );
    }

    switch (connection.status) {
      case ConnectionStatus.disconnected:
        color = w.inkMuted;
        text = l.connBadgeOffline;
        icon = Icons.cloud_off;
        break;
      case ConnectionStatus.connecting:
        color = w.inkMuted;
        text = l.connecting;
        icon = Icons.cloud_sync;
        break;
      case ConnectionStatus.relayConnected:
        color = w.inkMuted;
        text = connection.isNotPaired ? l.connBadgeNotPaired : l.connBadgeWaiting;
        icon = Icons.cloud_done;
        break;
      case ConnectionStatus.robotOnline:
        color = w.signal;
        text = l.connBadgeRobotOnline;
        icon = Icons.smart_toy;
        break;
      case ConnectionStatus.error:
        color = Theme.of(context).colorScheme.error;
        text = l.error;
        icon = Icons.error_outline;
        break;
      case ConnectionStatus.superseded:
        // B1: another device took over this account/device pair.
        color = w.inkMuted;
        text = l.connBadgeOtherDeviceActive;
        icon = Icons.swap_horiz;
        break;
    }

    // Demo mode override
    if (connection.isDemoMode) {
      color = w.ink;
      text = l.connBadgeDemo;
      icon = Icons.play_circle_outline;
    }

    return _PillContainer(
      color: color,
      icon: icon,
      text: text,
      live: connection.status == ConnectionStatus.robotOnline,
    );
  }
}

class _PillContainer extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String text;

  /// Robot online: the signal status chip (signal-glow fill).
  final bool live;

  const _PillContainer({
    required this.color,
    required this.icon,
    required this.text,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live ? w.signalGlow : w.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: live ? Colors.transparent : w.line),
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
