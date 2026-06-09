import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/controller_info.dart';
import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/controller_pairing_provider.dart';
import '../../theme/app_theme.dart';

/// Bump with each pubspec build so the on-screen debug strip identifies the
/// running binary (ends the "which build am I on" guesswork).
const String kControllerBuild = '131';

/// "Game Controller" screen — pair an Xbox controller directly to the robot.
///
/// The phone never uses its own Bluetooth. Every action is a command relayed to
/// the robot, which owns the BlueZ stack. Designed to be the field-friendly
/// replacement for SSH-ing into a deployed robot to re-pair a dropped pad.
class ControllerPairingScreen extends ConsumerStatefulWidget {
  const ControllerPairingScreen({super.key});

  @override
  ConsumerState<ControllerPairingScreen> createState() =>
      _ControllerPairingScreenState();
}

class _ControllerPairingScreenState
    extends ConsumerState<ControllerPairingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(controllerPairingProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    // Stop discovery on the robot when we leave so its BT radio isn't left
    // scanning. Guarded so it's a no-op on unsupported firmware.
    final notifier = ref.read(controllerPairingProvider.notifier);
    if (ref.read(controllerPairingProvider).scanning) {
      notifier.setScan(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(controllerPairingProvider);
    final notifier = ref.read(controllerPairingProvider.notifier);
    final connected = ref.watch(isConnectedAnyModeProvider);

    // Surface non-fatal messages as snackbars.
    ref.listen(controllerPairingProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
        notifier.clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Controller'),
        actions: [
          if (state.phase == ControllerPhase.ready)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: notifier.refreshStatus,
            ),
        ],
      ),
      body: Column(
        children: [
          _DebugStrip(state: state, connected: connected),
          Expanded(
            child: !connected
                ? const _CenteredHint(
                    icon: Icons.wifi_off,
                    title: 'Robot not connected',
                    body: 'Connect to your robot first, then come back to pair '
                        'a controller.',
                  )
                : switch (state.phase) {
                    ControllerPhase.unknown => const _CenteredHint(
                        icon: Icons.sync,
                        title: 'Checking robot…',
                        body: 'Asking the robot about its controllers.',
                        showSpinner: true,
                      ),
                    ControllerPhase.unsupported => _CenteredHint(
                        icon: Icons.help_outline,
                        title: 'No response from robot',
                        body: 'The robot didn\'t answer the controller check. '
                            'It may still be starting up, or its firmware may '
                            'not support controller pairing yet. Try again in '
                            'a moment.',
                        action: FilledButton.icon(
                          onPressed: notifier.retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ControllerPhase.ready => _ReadyBody(state: state),
                  },
          ),
        ],
      ),
    );
  }
}

/// Build 131: always-visible diagnostic strip so the live state is
/// screenshot-able without digging through the conn_trace log. Shows the build
/// number, the gate phase, whether the robot's controller events are actually
/// reaching the provider, and via which delivery path.
class _DebugStrip extends StatelessWidget {
  final ControllerPairingState state;
  final bool connected;
  const _DebugStrip({required this.state, required this.connected});

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'build $kControllerBuild · ${connected ? 'connected' : 'NOT connected'} · '
        'phase ${s.phase.name} · events ${s.eventsReceived}'
        '${s.lastEventType != null ? ' · last ${s.lastEventType} (${s.lastEventSource})' : ''}',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ReadyBody extends ConsumerWidget {
  final ControllerPairingState state;
  const _ReadyBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(controllerPairingProvider.notifier);
    final snapshot = state.snapshot;
    final active = snapshot.activeController;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _ActiveCard(controller: active),

        if (state.progressMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(state.progressMessage!,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),

        const Divider(),

        // ---- Saved controllers (trusted / bonded) ----
        const _SectionHeader('Saved Controllers'),
        if (snapshot.known.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'No saved controllers yet. Scan and pair one below — then trust '
              'it so the robot reconnects it automatically.',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
          )
        else
          ...snapshot.known.map((c) => _KnownTile(
                controller: c,
                busy: state.busyAddress == c.address,
                onReconnect: () => notifier.reconnect(c.address),
                onForget: () => _confirmForget(context, notifier, c),
                onTrustChanged: (v) => notifier.setTrusted(c.address, v),
              )),

        const Divider(),

        // ---- Scan / discovered ----
        const _SectionHeader('Add a Controller'),
        _ScanTile(scanning: snapshot.scanning, onToggle: notifier.setScan),
        if (snapshot.scanning && snapshot.discovered.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              controllerPairingHint(ControllerKind.generic),
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
          ),
        ...snapshot.discovered.map((c) => _DiscoveredTile(
              controller: c,
              busy: state.busyAddress == c.address,
              onPair: () => notifier.pair(c.address),
            )),
      ],
    );
  }

  Future<void> _confirmForget(
    BuildContext context,
    ControllerPairingNotifier notifier,
    ControllerInfo c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget controller?'),
        content: Text(
            'The robot will unpair "${c.name}" and stop auto-reconnecting it. '
            'You can pair it again later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) notifier.forget(c.address);
  }
}

/// Big status card at the top — the at-a-glance "is my pad connected".
class _ActiveCard extends StatelessWidget {
  final ControllerInfo? controller;
  const _ActiveCard({this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final connected = c?.connected == true;
    final color = connected ? AppTheme.connected : AppTheme.disconnected;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_esports, size: 40, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? (c?.name ?? 'Controller') : 'No controller connected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Connected' : 'Disconnected',
                      style: TextStyle(color: color, fontSize: 13),
                    ),
                    if (connected && c?.trusted == true) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.verified_user,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 2),
                      const Text('Trusted',
                          style: TextStyle(
                              color: AppTheme.primary, fontSize: 12)),
                    ],
                    if (connected && c?.battery != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.battery_full,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text('${c!.battery}%',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnownTile extends StatelessWidget {
  final ControllerInfo controller;
  final bool busy;
  final VoidCallback onReconnect;
  final VoidCallback onForget;
  final ValueChanged<bool> onTrustChanged;

  const _KnownTile({
    required this.controller,
    required this.busy,
    required this.onReconnect,
    required this.onForget,
    required this.onTrustChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.sports_esports,
            color: c.connected ? AppTheme.connected : AppTheme.textTertiary,
          ),
          title: Text(c.name),
          subtitle: Text(
            c.connected ? 'Connected' : 'Saved · not connected',
            style: TextStyle(
              color: c.connected ? AppTheme.connected : AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'reconnect') onReconnect();
                    if (v == 'forget') onForget();
                  },
                  itemBuilder: (_) => [
                    if (!c.connected)
                      const PopupMenuItem(
                          value: 'reconnect', child: Text('Reconnect')),
                    const PopupMenuItem(value: 'forget', child: Text('Forget')),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Auto-reconnect (trusted)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              Switch(
                value: c.trusted,
                onChanged: busy ? null : onTrustChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoveredTile extends StatelessWidget {
  final ControllerInfo controller;
  final bool busy;
  final VoidCallback onPair;

  const _DiscoveredTile({
    required this.controller,
    required this.busy,
    required this.onPair,
  });

  @override
  Widget build(BuildContext context) {
    final label = controllerKindLabel(controller.kind);
    final subtitle = controller.kind == ControllerKind.generic
        ? controller.address
        : '$label · ${controller.address}';
    return ListTile(
      leading: const Icon(Icons.bluetooth_searching, color: AppTheme.primary),
      title: Text(controller.name),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton(onPressed: onPair, child: const Text('Pair')),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final bool scanning;
  final ValueChanged<bool> onToggle;
  const _ScanTile({required this.scanning, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: scanning
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bluetooth),
      title: Text(scanning ? 'Scanning for controllers…' : 'Scan for controllers'),
      subtitle: Text(
        scanning
            ? 'Put your controller in pairing mode'
            : 'Robot will look for nearby controllers',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Switch(value: scanning, onChanged: onToggle),
      onTap: () => onToggle(!scanning),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool showSpinner;
  final Widget? action;

  const _CenteredHint({
    required this.icon,
    required this.title,
    required this.body,
    this.showSpinner = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 56, color: AppTheme.textTertiary),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
