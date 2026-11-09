import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/datasources/device_api.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

class DevicePairingScreen extends ConsumerStatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  ConsumerState<DevicePairingScreen> createState() =>
      _DevicePairingScreenState();
}

class _DevicePairingScreenState extends ConsumerState<DevicePairingScreen> {
  final _deviceIdController = TextEditingController();
  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    // Load devices when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pairedDevicesProvider.notifier).loadDevices();
    });
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  /// Build 94: client-side guard against pairing garbage that the relay will
  /// happily store but later refuse to clean up.
  static final _deviceIdRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{2,49}$');

  Future<void> _pairDevice() async {
    final l = context.l10n;
    final deviceId = _deviceIdController.text.trim().toLowerCase();
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.devicePairingEnterId)),
      );
      return;
    }
    if (!_deviceIdRegex.hasMatch(deviceId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.devicePairingInvalidId)),
      );
      return;
    }

    setState(() => _isPairing = true);

    final success =
        await ref.read(pairedDevicesProvider.notifier).pairDevice(deviceId);

    setState(() => _isPairing = false);

    if (success && mounted) {
      _deviceIdController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.devicePairingPaired(deviceId))),
      );
    }
  }

  Future<void> _unpairDevice(String deviceId) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.devicePairingUnpairTitle),
        content: Text(l.devicePairingUnpairBody(deviceId)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.link_off, size: 18),
            label: Text(l.devicePairingUnpair),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final outcome =
        await ref.read(pairedDevicesProvider.notifier).unpairDevice(deviceId);
    if (!mounted) return;

    switch (outcome) {
      case UnpairOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.devicePairingUnpaired(deviceId))),
        );
      case UnpairOutcome.orphaned:
        await _offerLocalDismiss(deviceId);
      case UnpairOutcome.error:
        // Error message is surfaced via the state.error banner.
        break;
    }
  }

  /// Build 94: relay said no such device — pairing row is orphaned. Offer to
  /// hide it locally so the list isn't stuck.
  Future<void> _offerLocalDismiss(String deviceId) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.devicePairingNotFoundTitle),
        content: Text(l.devicePairingNotFoundBody(deviceId)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.devicePairingKeep),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.visibility_off, size: 18),
            label: Text(l.devicePairingHide),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(pairedDevicesProvider.notifier).dismissLocally(deviceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.devicePairingHidden(deviceId))),
    );
  }

  void _selectDevice(PairedDevice device) {
    final label = device.name ?? device.deviceId;
    ref.read(pairedDevicesProvider.notifier).selectDevice(device.deviceId);
    // Optimistic feedback: jump straight to Home so the user watches the
    // connection/video come up (badge moves Waiting… → Robot Online) rather
    // than sitting on the list wondering if the tap registered. Build 110.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.devicePairingConnectingTo(label)),
          duration: const Duration(seconds: 2),
        ),
      );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final pairedDevicesState = ref.watch(pairedDevicesProvider);
    final activeDeviceId = ref.watch(deviceIdProvider);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.devicePairingTitle),
      ),
      body: Column(
        children: [
          // Pair new device section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: context.wimz.line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.devicePairingPairNew,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deviceIdController,
                        decoration: InputDecoration(
                          hintText: l.devicePairingIdHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        enabled: !_isPairing,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isPairing ? null : _pairDevice,
                      style: WimzTheme.goldButtonStyle(context),
                      icon: _isPairing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.wimz.inkOnGold,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(l.devicePairingPair),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error message
          if (pairedDevicesState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pairedDevicesState.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(pairedDevicesProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),

          // Paired devices list
          Expanded(
            child: pairedDevicesState.isLoading &&
                    pairedDevicesState.devices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : pairedDevicesState.devices.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(pairedDevicesProvider.notifier).loadDevices(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: pairedDevicesState.devices.length,
                          itemBuilder: (context, index) {
                            final device = pairedDevicesState.devices[index];
                            final isActive = device.deviceId == activeDeviceId;
                            final isOnline =
                                pairedDevicesState.isDeviceOnline(device.deviceId);

                            return _DeviceListItem(
                              device: device,
                              isActive: isActive,
                              isOnline: isOnline,
                              onTap: () => _selectDevice(device),
                              onUnpair: () => _unpairDevice(device.deviceId),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 64,
            color: context.wimz.inkMuted,
          ),
          const SizedBox(height: 16),
          Text(
            l.devicePairingNoDevices,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.wimz.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.devicePairingNoDevicesBody,
            style: TextStyle(color: context.wimz.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  final PairedDevice device;
  final bool isActive;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback onUnpair;

  const _DeviceListItem({
    required this.device,
    required this.isActive,
    required this.isOnline,
    required this.onTap,
    required this.onUnpair,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? context.wimz.surfaceSunken
            : context.wimz.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : context.wimz.line,
          width: isActive ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isOnline
                    ? context.wimz.signalGlow
                    : context.wimz.surfaceSunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy,
                color: isOnline ? context.wimz.signal : context.wimz.inkMuted,
                size: 28,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isOnline ? context.wimz.signal : context.wimz.inkMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.wimz.surfaceRaised, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name ?? device.deviceId,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l.devicePairingActive,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device.name != null)
              Text(
                device.deviceId,
                style: TextStyle(
                  fontSize: 12,
                  color: context.wimz.inkMuted,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isOnline ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: isOnline ? context.wimz.signal : context.wimz.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? l.devicePairingOnline : l.devicePairingOffline,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? context.wimz.signal : context.wimz.inkMuted,
                  ),
                ),
                if (device.lastSeen != null && !isOnline) ...[
                  Text(
                    l.devicePairingLastSeen(
                        _formatLastSeen(l, device.lastSeen!)),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.wimz.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.link_off, color: context.wimz.ink),
          onPressed: onUnpair,
          tooltip: l.devicePairingUnpairTooltip,
        ),
      ),
    );
  }

  String _formatLastSeen(AppLocalizations l, DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) {
      return l.devicePairingJustNow;
    } else if (diff.inMinutes < 60) {
      return l.devicePairingMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l.devicePairingHoursAgo(diff.inHours);
    } else {
      return l.devicePairingDaysAgo(diff.inDays);
    }
  }
}
