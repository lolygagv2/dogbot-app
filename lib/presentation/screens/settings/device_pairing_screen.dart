import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/device_api.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
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

  Future<void> _pairDevice() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device ID')),
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
        SnackBar(content: Text('Successfully paired $deviceId')),
      );
    }
  }

  Future<void> _unpairDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: Text('Are you sure you want to unpair $deviceId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(pairedDevicesProvider.notifier).unpairDevice(deviceId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unpaired $deviceId')),
        );
      }
    }
  }

  void _selectDevice(String deviceId) {
    ref.read(pairedDevicesProvider.notifier).selectDevice(deviceId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Now controlling $deviceId')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairedDevicesState = ref.watch(pairedDevicesProvider);
    final activeDeviceId = ref.watch(deviceIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Pairing'),
      ),
      body: Column(
        children: [
          // Pair new device section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAIR NEW DEVICE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
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
                          hintText: 'Enter device ID (e.g., wimz_robot_01)',
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
                      icon: _isPairing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Pair'),
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
              color: AppTheme.error.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pairedDevicesState.error!,
                      style: TextStyle(color: AppTheme.error),
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
                              onTap: () => _selectDevice(device.deviceId),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Paired Devices',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a device ID above to pair your WIM-Z',
            style: TextStyle(color: AppTheme.textTertiary),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.primary : AppTheme.glassBorder,
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
                    ? AppTheme.accent.withOpacity(0.1)
                    : AppTheme.textTertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy,
                color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
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
                  color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface, width: 2),
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
                  color: isActive ? AppTheme.primary : null,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
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
                  color: AppTheme.textTertiary,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isOnline ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
                  ),
                ),
                if (device.lastSeen != null && !isOnline) ...[
                  Text(
                    ' - Last seen ${_formatLastSeen(device.lastSeen!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.link_off, color: AppTheme.error),
          onPressed: onUnpair,
          tooltip: 'Unpair device',
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
