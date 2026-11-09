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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    final isLocal = ref.watch(isLocalModeProvider);
    final paired = ref.watch(pairedDevicesProvider);
    final activeId = ref.watch(deviceIdProvider);
    final hasSelected = ref.watch(hasSelectedDeviceProvider);

    if (isLocal) {
      return _Card(
        icon: Icons.wifi_tethering,
        iconColor: w.signal,
        title: l.robotCardLocal,
        subtitle: l.homeLocalRobot,
      );
    }

    final hasRobot = hasSelected && paired.devices.isNotEmpty;
    if (!hasRobot) {
      return _Card(
        icon: Icons.smart_toy_outlined,
        iconColor: w.inkMuted,
        title: l.robotCardNonePaired,
        subtitle: paired.isLoading ? l.loading : l.robotCardNoneBody,
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
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
      iconColor: online ? w.signal : w.inkMuted,
      title: name,
      subtitle: online ? l.devicePairingOnline : l.devicePairingOffline,
      subtitleColor: online ? w.signal : w.inkMuted,
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: w.line),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor ?? w.inkMuted,
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
