import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final telemetry = ref.watch(telemetryProvider);
    final deviceId = ref.watch(deviceIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Device Pairing'),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Active Robot'),
            subtitle: Text(deviceId),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/device-pairing'),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Manage Devices'),
            subtitle: const Text('Pair, unpair, and switch between robots'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/device-pairing'),
          ),
          const Divider(),

          _SectionHeader('Connection'),
          ListTile(
            leading: Icon(
              connection.isConnected ? Icons.wifi : Icons.wifi_off,
              color: connection.isConnected ? Colors.green : Colors.red,
            ),
            title: Text(connection.isConnected ? 'Connected' : 'Disconnected'),
            subtitle: Text('${connection.host}:${connection.port}'),
            trailing: TextButton(
              onPressed: () async {
                await ref.read(connectionProvider.notifier).disconnect();
                if (context.mounted) context.go('/connect');
              },
              child: const Text('Disconnect'),
            ),
          ),
          const Divider(),

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
          ListTile(
            leading: const Icon(Icons.cookie),
            title: const Text('Treats Remaining'),
            trailing: Text('${telemetry.treatsRemaining}'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Current Mode'),
            trailing: Text(telemetry.mode.toUpperCase()),
          ),
          const Divider(),

          _SectionHeader('Calibration'),
          _MotorTrimSlider(),
          const Divider(),

          _SectionHeader('Training'),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Voice Commands'),
            subtitle: const Text('Record custom voice commands for your dog'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/voice-setup'),
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
              const Text('-20%', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: settings.motorTrimRight,
                  min: -0.2,
                  max: 0.2,
                  divisions: 40,
                  label: '${trimPercent > 0 ? '+' : ''}$trimPercent%',
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setMotorTrimRight(value);
                  },
                ),
              ),
              const Text('+20%', style: TextStyle(fontSize: 12)),
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
    final secondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

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

void _showDeviceIdDialog(BuildContext context, WidgetRef ref, String currentId) {
  final controller = TextEditingController(text: currentId);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pair Robot'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Robot ID',
          hintText: 'e.g., wimz_robot_01',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final newId = controller.text.trim();
            if (newId.isNotEmpty) {
              ref.read(deviceIdProvider.notifier).setDeviceId(newId);
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
