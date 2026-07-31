import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_client.dart';
import '../../../core/services/local_connection_service.dart';
import '../../../core/utils/conn_trace.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/network_state_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Build 146 (robot contract 2026-07-26): when a cloud session loses the
/// robot, it is often sitting on its own hotspot (WiFi loss → AP fallback
/// within ~45-60s, single SSID `WIMZ-<serial>` / `wimzsetup`). The latest
/// `network_state` breadcrumb cached per robot carries those credentials, so
/// instead of a dead "Offline" badge the app can say where the robot probably
/// is and offer the switch.
class LocalApOfflineBanner extends ConsumerStatefulWidget {
  const LocalApOfflineBanner({super.key});

  @override
  ConsumerState<LocalApOfflineBanner> createState() =>
      _LocalApOfflineBannerState();
}

class _LocalApOfflineBannerState extends ConsumerState<LocalApOfflineBanner> {
  bool _connecting = false;

  // Anti-spam state machine (2026-07-30, Morgan's field feedback):
  // - the robot must be CONTINUOUSLY unreachable for [_showAfter] before the
  //   banner appears — connection-status flaps during login/reconnect used to
  //   flash it on every cloud sign-in;
  // - once visible it auto-hides after [_visibleFor];
  // - any hide (auto or the ✕ button) snoozes it for [_snoozeFor] so a robot
  //   that is simply powered off doesn't nag all day. A robot coming back
  //   online resets the episode; the snooze survives it.
  static const _showAfter = Duration(seconds: 8);
  static const _visibleFor = Duration(seconds: 45);
  static const _snoozeFor = Duration(minutes: 30);

  bool _visible = false;
  bool _eligibleNow = false;
  Timer? _showDelay;
  Timer? _autoHide;
  DateTime? _snoozeUntil;

  bool get _snoozed =>
      _snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!);

  void _onEligibleChanged(bool eligible) {
    if (eligible == _eligibleNow) return;
    _eligibleNow = eligible;
    if (eligible) {
      if (_snoozed) return;
      _showDelay?.cancel();
      _showDelay = Timer(_showAfter, () {
        if (!mounted || !_eligibleNow || _snoozed) return;
        setState(() => _visible = true);
        _autoHide?.cancel();
        _autoHide = Timer(_visibleFor, () {
          if (mounted) _dismiss(auto: true);
        });
      });
    } else {
      // Robot reachable again (or mode changed) — reset the episode. No
      // setState: the current build already renders nothing for !eligible.
      _showDelay?.cancel();
      _autoHide?.cancel();
      _visible = false;
    }
  }

  void _dismiss({bool auto = false}) {
    _showDelay?.cancel();
    _autoHide?.cancel();
    _snoozeUntil = DateTime.now().add(_snoozeFor);
    if (_visible && mounted) setState(() => _visible = false);
    connTrace('local-ap-banner',
        auto ? 'auto-hidden, snoozed 30m' : 'dismissed, snoozed 30m');
  }

  @override
  void dispose() {
    _showDelay?.cancel();
    _autoHide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final connection = ref.watch(connectionProvider);
    final networkState = ref.watch(targetRobotNetworkStateProvider);
    final localAp = networkState?.localAp;

    // Cloud session with the robot unreachable, and we know its AP.
    final robotUnreachable = connection.status == ConnectionStatus.relayConnected ||
        connection.status == ConnectionStatus.error;
    final eligible =
        !settings.localModeEnabled && robotUnreachable && localAp != null;
    _onEligibleChanged(eligible);
    if (!eligible || !_visible) return const SizedBox.shrink();

    return Material(
      color: AppTheme.primary.withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_find, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Robot may be on its own hotspot — if you\'re nearby, join '
                '"${localAp.ssid}" (password ${localAp.password}) and switch '
                'to Local Mode.',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            _connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => switchToLocalMode(
                      context,
                      ref,
                      localAp,
                      onBusy: (busy) {
                        if (mounted) setState(() => _connecting = busy);
                      },
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('GO LOCAL',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Dismiss',
              onPressed: () => _dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared switch-to-local flow (same path the login screen's "Connect to
/// Robot" uses): flip the local-mode setting, auto-discover the robot (races
/// the AP address and the last-good IP), then mark the connection local.
Future<void> switchToLocalMode(
  BuildContext context,
  WidgetRef ref,
  RobotLocalAp localAp, {
  void Function(bool busy)? onBusy,
}) async {
  onBusy?.call(true);
  connTrace('local-switch', 'attempting ${localAp.ssid} @ ${localAp.ip}');
  await ref.read(settingsProvider.notifier).setLocalModeEnabled(true);
  try {
    final success = await ref
        .read(localConnectionProvider.notifier)
        .connectAuto()
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (success) {
      final local = ref.read(localConnectionProvider);
      ref
          .read(connectionProvider.notifier)
          .setLocalConnected(local.robotIp ?? localAp.ip, local.port);
      connTrace('local-switch', 'connected ${local.robotIp}');
    } else {
      // Roll the setting back — a failed switch must not strand the app in
      // local mode with no robot.
      await ref.read(settingsProvider.notifier).setLocalModeEnabled(false);
      connTrace('local-switch', 'failed — reverted to cloud');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Couldn\'t reach the robot. Join "${localAp.ssid}" '
              '(password ${localAp.password}) in WiFi settings first, '
              'then try again.'),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  } catch (e) {
    await ref.read(settingsProvider.notifier).setLocalModeEnabled(false);
    connTrace('local-switch', 'error $e — reverted to cloud');
  } finally {
    onBusy?.call(false);
  }
}

/// Settings tile (cloud mode, robot online): command the robot onto its
/// hotspot and switch this session to local. Flow per the robot contract:
/// send `local_mode` over relay → await `local_mode_starting` (carries the
/// AP credentials; also cached by [networkStateProvider]) → user joins the
/// AP → connect over `/ws/local`. Local mode is sticky robot-side until an
/// explicit cloud-mode command, reboot, or 10 min with no phone attached.
class LocalModeSwitchTile extends ConsumerStatefulWidget {
  const LocalModeSwitchTile({super.key});

  @override
  ConsumerState<LocalModeSwitchTile> createState() =>
      _LocalModeSwitchTileState();
}

class _LocalModeSwitchTileState extends ConsumerState<LocalModeSwitchTile> {
  bool _requesting = false;

  Future<void> _requestLocalMode() async {
    setState(() => _requesting = true);
    final ws = ref.read(websocketClientProvider);

    // Await the robot's local_mode_starting ack (it also refreshes the cached
    // credentials). Subscribe BEFORE sending so a fast ack can't be missed.
    final ackFuture = ws.eventStream
        .where((e) => e.type == 'local_mode_starting')
        .first
        .timeout(const Duration(seconds: 10));
    ws.sendCommand('local_mode');
    connTrace('local-switch', 'local_mode command sent');

    RobotLocalAp? localAp;
    try {
      final ack = await ackFuture;
      localAp = RobotLocalAp.fromJson(ack.data['local_ap']);
    } on TimeoutException {
      connTrace('local-switch', 'no local_mode_starting within 10s');
    }
    // Fall back to the cached breadcrumb — same credentials.
    localAp ??= ref.read(targetRobotNetworkStateProvider)?.localAp;

    if (!mounted) return;
    setState(() => _requesting = false);

    if (localAp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Robot didn\'t confirm hotspot start and no cached hotspot info '
            'is available. Update the robot and try again.'),
      ));
      return;
    }

    final ap = localAp;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join the robot\'s hotspot'),
        content: Text(
          'The robot is starting its hotspot.\n\n'
          '1. Open WiFi settings on this phone\n'
          '2. Join "${ap.ssid}"\n    password: ${ap.password}\n'
          '3. Come back and tap Connect\n\n'
          'The robot stays on its hotspot until you switch back to cloud '
          'mode (or 10 minutes with no phone attached).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              switchToLocalMode(context, ref, ap);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(connectionProvider).isRobotOnline;
    return ListTile(
      leading: const Icon(Icons.wifi_tethering, color: AppTheme.primary),
      title: const Text('Switch to Local Mode'),
      subtitle: const Text('Robot starts its hotspot; phone connects directly'),
      trailing: _requesting
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right),
      enabled: isConnected && !_requesting,
      onTap: isConnected && !_requesting ? _requestLocalMode : null,
    );
  }
}
