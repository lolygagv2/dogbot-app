import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Robot state on the dog profile (product rule 2026-11-06: pairing is
/// optional). Three states: connected directly (local-AP), paired (name +
/// online/offline, tap to manage), or "No robot paired" with a Pair button.
/// Never blocks anything else on the profile — a dog is a complete profile
/// with or without a robot.
class RobotStatusCard extends ConsumerStatefulWidget {
  const RobotStatusCard({super.key});

  @override
  ConsumerState<RobotStatusCard> createState() => _RobotStatusCardState();
}

class _RobotStatusCardState extends ConsumerState<RobotStatusCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(isLocalModeProvider)) return;
      final s = ref.read(pairedDevicesProvider);
      if (s.devices.isEmpty && !s.isLoading) {
        ref.read(pairedDevicesProvider.notifier).loadDevices();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isLocal = ref.watch(isLocalModeProvider);
    final paired = ref.watch(pairedDevicesProvider);
    final activeId = ref.watch(deviceIdProvider);
    final hasSelected = ref.watch(hasSelectedDeviceProvider);

    if (isLocal) {
      return _Card(
        icon: Icons.wifi_tethering,
        iconColor: AppTheme.accent,
        title: l.robotCardLocal,
        subtitle: l.homeLocalRobot,
      );
    }

    final hasRobot = hasSelected && paired.devices.isNotEmpty;
    if (!hasRobot) {
      return _Card(
        icon: Icons.smart_toy_outlined,
        iconColor: AppTheme.textTertiary,
        title: l.robotCardNonePaired,
        subtitle: paired.isLoading ? l.loading : l.robotCardNoneBody,
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => context.push('/device-pairing'),
          icon: const Icon(Icons.add_link, size: 18),
          label: Text(l.robotCardPair),
        ),
      );
    }

    final match = paired.devices.where((d) => d.deviceId == activeId);
    final name = match.isNotEmpty
        ? (match.first.name ?? match.first.deviceId)
        : activeId;
    final online = paired.isDeviceOnline(activeId) ||
        (match.isNotEmpty && match.first.isOnline);
    return _Card(
      icon: Icons.smart_toy,
      iconColor: online ? AppTheme.accent : AppTheme.textTertiary,
      title: name,
      subtitle: online ? l.devicePairingOnline : l.devicePairingOffline,
      subtitleColor: online ? AppTheme.accent : AppTheme.textTertiary,
      trailing: TextButton(
        onPressed: () => context.push('/device-pairing'),
        child: Text(l.robotCardManage),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  const _Card({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor ?? AppTheme.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
