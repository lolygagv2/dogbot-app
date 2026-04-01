import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/push_to_talk_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../domain/providers/wifi_config_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load paired devices on screen open (skip in local mode — no relay API)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isLocal = ref.read(settingsProvider).localModeEnabled;
      if (!isLocal) {
        ref.read(pairedDevicesProvider.notifier).loadDevices();
      }
    });
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showRecordingDiagnostics(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _RecordingDiagnosticsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final settings = ref.watch(settingsProvider);
    final isLocalMode = settings.localModeEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Section 1: Connection Mode
          _SectionHeader('Connection Mode'),
          const _LocalModeTile(),
          const Divider(),

          // Section 2: Connection Status
          _SectionHeader('Connection Status'),
          const _SimpleConnectionTile(),
          const Divider(),

          // Section 3: Manage Devices (cloud mode only)
          if (!isLocalMode) ...[
            _SectionHeader('Manage Devices'),
            const _InlineDeviceList(),
            const Divider(),
          ],

          // WiFi Setup Help
          const _WiFiSetupHelp(),
          const Divider(),

          _SectionHeader('Robot Status'),
          ListTile(
            leading: Icon(
              telemetry.isCharging ? Icons.battery_charging_full : Icons.battery_full,
              color: telemetry.battery > 20 ? Colors.green : Colors.red,
            ),
            title: const Text('Battery'),
            trailing: Text(
              '${telemetry.battery.toInt()}%${telemetry.isCharging ? ' ⚡' : ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: const Text('Temperature'),
            trailing: Text(telemetry.temperature > 0 ? '${telemetry.temperature.toInt()}°C' : 'N/A'),
          ),
          _TreatsRemainingTile(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Current Mode'),
            trailing: Text(telemetry.mode.toUpperCase()),
          ),
          const Divider(),

          _SectionHeader('Calibration'),
          _MotorTrimSlider(),
          const Divider(),

          _SectionHeader('Camera'),
          const _CameraTrackingTile(),
          const Divider(),

          _SectionHeader('Audio'),
          const _BackgroundAudioTile(),
          const Divider(),

          _SectionHeader('Training'),
          const _DailyLimitTile(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Training Scheduler'),
            subtitle: const Text('Schedule automatic training sessions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/scheduler'),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Voice Commands'),
            subtitle: const Text('Record custom voice commands for your dog'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/voice-setup'),
          ),
          const Divider(),

          _SectionHeader('Diagnostics'),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Test Recording'),
            subtitle: const Text('Run recording diagnostics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRecordingDiagnostics(context, ref),
          ),
          const Divider(),

          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('WIM-Z App'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('API Version'),
            subtitle: Text('v1'),
          ),
          const Divider(),

          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out'),
            subtitle: Text(
              ref.watch(authProvider).email ?? '',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
/// Host selection dropdown — WIMZ Server (relay) or WIMZ Robot (local)
class _LocalModeTile extends ConsumerStatefulWidget {
  const _LocalModeTile();

  @override
  ConsumerState<_LocalModeTile> createState() => _LocalModeTileState();
}

class _LocalModeTileState extends ConsumerState<_LocalModeTile> {
  void _showWifiConfigSheet(BuildContext context) {
    ref.read(wifiConfigProvider.notifier).reset();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _WifiConfigSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _switchToLocal() async {
    // Disconnect any existing relay connection
    await ref.read(connectionProvider.notifier).disconnect();
    // Connect directly to robot hotspot
    final success = await ref
        .read(localConnectionProvider.notifier)
        .connectViaHotspot();

    if (success) {
      // Mark connectionProvider as connected so all controls work
      ref.read(connectionProvider.notifier).setLocalConnected();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Connected to WIMZ Robot'
              : 'Could not connect. Make sure you\'re on the WIMZ-Demo WiFi network.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _switchToRelay() async {
    // Disconnect local connection
    await ref.read(localConnectionProvider.notifier).disconnect();
    // Reconnect to relay with saved credentials
    await ref.read(connectionProvider.notifier).reconnect();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switching to WIMZ Server...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final localConn = ref.watch(localConnectionProvider);
    final isLocal = settings.localModeEnabled;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<bool>(
            value: isLocal,
            decoration: InputDecoration(
              prefixIcon: Icon(
                isLocal ? Icons.wifi : Icons.cloud,
                color: isLocal ? AppTheme.accent : AppTheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(
                value: false,
                child: Text('WIMZ Server — api.wimzai.com'),
              ),
              DropdownMenuItem(
                value: true,
                child: Text('WIMZ Robot — 192.168.4.1'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await ref.read(settingsProvider.notifier).setLocalModeEnabled(value);
              if (value) {
                _switchToLocal();
              } else {
                _switchToRelay();
              }
            },
          ),
        ),
        if (isLocal) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Direct connection via local WiFi (no internet needed)',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
          // Network status and WiFi config hidden for now — Pi doesn't have
          // /system/network-status or /system/wifi/scan endpoints yet
          if (localConn.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                localConn.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Cloud relay connection (requires internet & login)',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Simplified connection tile - shows cloud connection status only (local mode disabled)
class _SimpleConnectionTile extends ConsumerWidget {
  const _SimpleConnectionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local mode temporarily disabled for debugging
    final connection = ref.watch(connectionProvider);
    final deviceId = ref.watch(deviceIdProvider);

    final isRobotOnline = connection.status == ConnectionStatus.robotOnline;

    return ListTile(
      leading: Icon(
        isRobotOnline ? Icons.smart_toy : Icons.cloud_off,
        color: isRobotOnline ? AppTheme.accent : AppTheme.textTertiary,
        size: 32,
      ),
      title: Text(
        isRobotOnline ? 'Connected to $deviceId' : 'Not connected',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isRobotOnline ? AppTheme.accent : null,
        ),
      ),
      subtitle: isRobotOnline
          ? null
          : Text(
              connection.status == ConnectionStatus.connecting
                  ? 'Connecting...'
                  : 'Tap a device below to connect',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
      trailing: isRobotOnline
          ? TextButton(
              onPressed: () async {
                await ref.read(connectionProvider.notifier).disconnect();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Disconnect'),
            )
          : null,
    );
  }
}

/// Inline device list with online/offline indicators
class _InlineDeviceList extends ConsumerWidget {
  const _InlineDeviceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairedDevices = ref.watch(pairedDevicesProvider);
    final activeDeviceId = ref.watch(deviceIdProvider);

    if (pairedDevices.isLoading && pairedDevices.devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (pairedDevices.devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.devices, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No paired devices',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/device-pairing'),
              icon: const Icon(Icons.add),
              label: const Text('Add Device'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...pairedDevices.devices.map((device) {
          final isActive = device.deviceId == activeDeviceId;
          final isOnline = pairedDevices.isDeviceOnline(device.deviceId);

          return Dismissible(
            key: Key(device.deviceId),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppTheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unpair Device'),
                  content: Text('Unpair ${device.deviceId}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                      child: const Text('Unpair'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              ref.read(pairedDevicesProvider.notifier).unpairDevice(device.deviceId);
            },
            child: ListTile(
              leading: Stack(
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
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
                  Text(device.name ?? device.deviceId),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isOnline ? AppTheme.accent : AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
              trailing: isOnline && !isActive
                  ? TextButton(
                      onPressed: () {
                        print('Settings: User tapped to select device ${device.deviceId}');
                        ref.read(pairedDevicesProvider.notifier).selectDevice(device.deviceId);
                      },
                      child: const Text('Connect'),
                    )
                  : const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              onTap: () {
                print('Settings: User tapped device ${device.deviceId} (online=$isOnline, active=$isActive)');
                if (isOnline && !isActive) {
                  ref.read(pairedDevicesProvider.notifier).selectDevice(device.deviceId);
                }
              },
            ),
          );
        }),
        // Add device button
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Add Device'),
          onTap: () => context.push('/device-pairing'),
        ),
      ],
    );
  }
}

/// Treats remaining display — reads from treatsRemainingProvider (handles null/-1)
class _TreatsRemainingTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(treatsRemainingProvider);
    final display = count == null ? '\u2014' : (count <= 0 ? '0 (refill needed)' : '$count');

    return ListTile(
      leading: const Icon(Icons.cookie),
      title: const Text('Treats Remaining'),
      trailing: Text(display),
    );
  }
}

/// Daily treat limit toggle with count slider
class _DailyLimitTile extends ConsumerWidget {
  const _DailyLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.cookie,
            color: settings.dailyLimitEnabled ? AppTheme.warning : AppTheme.textTertiary,
          ),
          title: const Text('Daily Treat Limit'),
          subtitle: Text(
            settings.dailyLimitEnabled
                ? 'Max ${settings.dailyLimitCount} auto-treats per day'
                : 'No daily limit — unlimited auto-treats',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          value: settings.dailyLimitEnabled,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setDailyLimitEnabled(value);
          },
        ),
        if (settings.dailyLimitEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('5', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: settings.dailyLimitCount.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${settings.dailyLimitCount}',
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setDailyLimitCount(value.round());
                    },
                  ),
                ),
                const Text('100', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Camera tracking toggle (Build 38)
class _CameraTrackingTile extends ConsumerWidget {
  const _CameraTrackingTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SwitchListTile(
      secondary: Icon(
        settings.cameraTrackingEnabled ? Icons.videocam : Icons.videocam_off,
        color: settings.cameraTrackingEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: const Text('Camera Track Dog'),
      subtitle: Text(
        settings.cameraTrackingEnabled
            ? 'Camera follows dog during coach/mission mode'
            : 'Camera stays centered',
        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
      ),
      value: settings.cameraTrackingEnabled,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setCameraTrackingEnabled(value);
      },
    );
  }
}

/// Background audio toggle
class _BackgroundAudioTile extends ConsumerWidget {
  const _BackgroundAudioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SwitchListTile(
      secondary: Icon(
        Icons.headphones,
        color: settings.backgroundAudioEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: const Text('Background Audio'),
      subtitle: Text(
        settings.backgroundAudioEnabled
            ? 'Keep listening when app is in background'
            : 'Audio stops when app is backgrounded',
        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
      ),
      value: settings.backgroundAudioEnabled,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setBackgroundAudioEnabled(value);
      },
    );
  }
}

/// Motor trim slider widget
class _MotorTrimSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final trimPercent = (settings.motorTrimRight * 100).round();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Motor Trim (Right)'),
          subtitle: Text(
            trimPercent == 0
                ? 'No adjustment'
                : trimPercent > 0
                    ? 'Slowing right motor by $trimPercent%'
                    : 'Speeding right motor by ${-trimPercent}%',
          ),
          trailing: TextButton(
            onPressed: trimPercent != 0
                ? () => ref.read(settingsProvider.notifier).resetMotorTrim()
                : null,
            child: const Text('Reset'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('-50%', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: settings.motorTrimRight,
                  min: -0.5,
                  max: 0.5,
                  divisions: 100,
                  label: '${trimPercent > 0 ? '+' : ''}$trimPercent%',
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setMotorTrimRight(value);
                  },
                ),
              ),
              const Text('+50%', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'If robot drifts LEFT, increase trim. If it drifts RIGHT, decrease trim.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// WiFi setup help expandable section
class _WiFiSetupHelp extends StatelessWidget {
  const _WiFiSetupHelp();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ExpansionTile(
      leading: const Icon(Icons.wifi_tethering),
      title: const Text('WiFi Setup Help'),
      subtitle: const Text('How to connect your robot'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connecting Your WIM-Z to WiFi',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _SetupStep(number: '1', text: 'Power on your WIM-Z robot'),
        _SetupStep(
          number: '2',
          text: 'If not connected to WiFi, it creates a hotspot called "WIMZ-XXXX"',
        ),
        _SetupStep(
          number: '3',
          text: 'On your phone, go to Settings → WiFi',
        ),
        _SetupStep(
          number: '4',
          text: 'Connect to "WIMZ-XXXX"',
          detail: 'Password: wimzsetup',
        ),
        _SetupStep(
          number: '5',
          text: 'Open your browser and go to:',
          detail: 'http://192.168.4.1',
        ),
        _SetupStep(
          number: '6',
          text: 'Select your home WiFi network and enter the password',
        ),
        _SetupStep(
          number: '7',
          text: 'Robot will reboot and connect to your network',
        ),
        _SetupStep(
          number: '8',
          text: 'Return to this app and pair with your robot',
        ),

        const SizedBox(height: 16),
        Text(
          'LED Status Guide',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _LedIndicator(
          color: Colors.cyan,
          label: 'Spinning cyan',
          meaning: 'Searching for WiFi',
        ),
        _LedIndicator(
          color: Colors.blue,
          label: 'Pulsing blue',
          meaning: 'Setup mode (connect to WIMZ hotspot)',
        ),
        _LedIndicator(
          color: Colors.green,
          label: 'Solid green',
          meaning: 'Connected to WiFi',
        ),
        _LedIndicator(
          color: Colors.red,
          label: 'Pulsing red',
          meaning: 'Error',
        ),
      ],
    );
  }
}

/// A single setup step with number badge
class _SetupStep extends StatelessWidget {
  final String number;
  final String text;
  final String? detail;

  const _SetupStep({
    required this.number,
    required this.text,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// LED status indicator row
class _LedIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final String meaning;

  const _LedIndicator({
    required this.color,
    required this.label,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label = ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network status indicator — polls GET /system/network-status every 5s
class _NetworkStatusIndicator extends ConsumerStatefulWidget {
  const _NetworkStatusIndicator();

  @override
  ConsumerState<_NetworkStatusIndicator> createState() =>
      _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState
    extends ConsumerState<_NetworkStatusIndicator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wifiConfigProvider.notifier).startStatusPolling();
    });
  }

  @override
  void dispose() {
    // Don't stop polling here — provider lifecycle handles it.
    // But if we want to be polite when the tile collapses:
    // We can't call ref in dispose, so the provider's own dispose handles cleanup.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(wifiConfigProvider).networkStatus;

    if (status == null) {
      return const SizedBox.shrink();
    }

    final modeLabel = status.isAP ? 'Hotspot (AP)' : status.isWifi ? 'WiFi' : status.mode;
    final modeColor = status.isAP ? AppTheme.warning : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: modeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isAP ? Icons.wifi_tethering : Icons.wifi,
                size: 16,
                color: modeColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Robot Network',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: modeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statusRow('Mode', modeLabel),
          if (status.networkName.isNotEmpty)
            _statusRow('Network', status.networkName),
          if (status.ipAddress.isNotEmpty)
            _statusRow('IP', status.ipAddress),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// WiFi configuration bottom sheet
class _WifiConfigSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _WifiConfigSheet({required this.scrollController});

  @override
  ConsumerState<_WifiConfigSheet> createState() => _WifiConfigSheetState();
}

class _WifiConfigSheetState extends ConsumerState<_WifiConfigSheet> {
  final _passwordController = TextEditingController();
  String? _selectedSsid;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Start scanning immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wifiConfigProvider.notifier).scanNetworks();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wifiState = ref.watch(wifiConfigProvider);
    final localConn = ref.watch(localConnectionProvider);

    // If we sent connect and local connection dropped, notify provider
    if (wifiState.step == WifiConfigStep.connectSent && !localConn.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wifiConfigProvider.notifier).onConnectionLost();
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Configure Robot WiFi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (wifiState.step == WifiConfigStep.scanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _buildSheetContent(wifiState),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(WifiConfigState wifiState) {
    switch (wifiState.step) {
      case WifiConfigStep.idle:
      case WifiConfigStep.scanning:
        return _buildScanningView();

      case WifiConfigStep.scanComplete:
        return _buildNetworkList(wifiState);

      case WifiConfigStep.scanError:
        return _buildErrorView(wifiState.errorMessage ?? 'Scan failed');

      case WifiConfigStep.connecting:
        return _buildConnectingView();

      case WifiConfigStep.connectSent:
        return _buildWaitingView();

      case WifiConfigStep.connectionLost:
        return _buildConnectionLostView();
    }
  }

  Widget _buildScanningView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for WiFi networks...'),
        ],
      ),
    );
  }

  Widget _buildNetworkList(WifiConfigState wifiState) {
    final networks = wifiState.networks;

    return Column(
      children: [
        Expanded(
          child: networks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: AppTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('No WiFi networks found'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(wifiConfigProvider.notifier).scanNetworks(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: networks.length,
                  itemBuilder: (context, index) {
                    final network = networks[index];
                    final isSelected = _selectedSsid == network.ssid;

                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            _signalIcon(network.signal),
                            color: isSelected ? AppTheme.primary : null,
                          ),
                          title: Text(
                            network.ssid,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : null,
                            ),
                          ),
                          subtitle: Text(
                            '${_signalLabel(network.signal)}${network.security.isNotEmpty ? ' · ${network.security}' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            setState(() => _selectedSsid = network.ssid);
                          },
                        ),
                        // Password field expands under selected network
                        if (isSelected)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter WiFi password',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() =>
                                            _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(wifiConfigProvider.notifier)
                                          .connectToNetwork(
                                            _selectedSsid!,
                                            _passwordController.text,
                                          );
                                    },
                                    icon: const Icon(Icons.wifi),
                                    label: const Text('Connect'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: AppTheme.background,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (wifiState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              wifiState.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        // Rescan button at bottom
        if (networks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedSsid = null);
                  ref.read(wifiConfigProvider.notifier).scanNetworks();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan Again'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(wifiConfigProvider.notifier).scanNetworks(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Robot is connecting to WiFi...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a moment.',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.warning),
            SizedBox(height: 16),
            Text(
              'Robot is switching to WiFi...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'The local hotspot will shut down.\n'
              'Your connection may drop shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionLostView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'WiFi command sent!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Robot is switching to WiFi. '
              'Connect your phone to the same WiFi network, '
              'then disable Local Mode to use relay connection.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _signalIcon(int signal) {
    // signal is typically negative dBm (e.g., -30 = excellent, -90 = poor)
    // or could be 0-100 percentage — handle both
    final strength = signal < 0 ? signal : -(100 - signal);
    if (strength > -50) return Icons.wifi;
    if (strength > -70) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  String _signalLabel(int signal) {
    final strength = signal < 0 ? signal : -(100 - signal);
    if (strength > -50) return 'Excellent';
    if (strength > -70) return 'Good';
    if (strength > -80) return 'Fair';
    return 'Weak';
  }
}

/// Recording diagnostics dialog
class _RecordingDiagnosticsDialog extends ConsumerStatefulWidget {
  const _RecordingDiagnosticsDialog();

  @override
  ConsumerState<_RecordingDiagnosticsDialog> createState() =>
      _RecordingDiagnosticsDialogState();
}

class _RecordingDiagnosticsDialogState
    extends ConsumerState<_RecordingDiagnosticsDialog> {
  String _results = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results = 'Running diagnostics...\n';
    });

    try {
      final notifier = ref.read(pushToTalkProvider.notifier);
      final results = await notifier.runDiagnostics();
      setState(() {
        _results = results;
        _isRunning = false;
      });
    } catch (e, stack) {
      setState(() {
        _results = 'DIAGNOSTICS ERROR: $e\n\nStack: $stack';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: AppTheme.accent),
          const SizedBox(width: 8),
          const Text('Recording Diagnostics'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRunning)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Running tests...'),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _results,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRunning ? null : _runDiagnostics,
          child: const Text('Run Again'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
