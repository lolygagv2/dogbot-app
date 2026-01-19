import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final telemetry = ref.watch(telemetryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
          
          _SectionHeader('Robot Status'),
          ListTile(
            leading: const Icon(Icons.battery_full),
            title: const Text('Battery'),
            trailing: Text('${telemetry.battery.toInt()}%'),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: const Text('Temperature'),
            trailing: Text('${telemetry.temperature.toInt()}C'),
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
