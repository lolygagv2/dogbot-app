import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../theme/app_theme.dart';

/// Connection screen - connects to WIM-Z after authentication
class ConnectScreen extends ConsumerStatefulWidget {
  final String? initialHost;
  final int? initialPort;

  const ConnectScreen({
    super.key,
    this.initialHost,
    this.initialPort,
  });

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _autoConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  void _loadDefaults() {
    // Use passed parameters first, then saved connection, then defaults
    final connection = ref.read(connectionProvider);
    _hostController.text = widget.initialHost ??
        connection.host ??
        AppConstants.defaultHost;
    _portController.text = (widget.initialPort ??
        connection.port ??
        AppConstants.defaultPort).toString();

    // Auto-connect if we have initial host/port from login
    if (widget.initialHost != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connect();
      });
      _autoConnecting = true;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8000;

    final success =
        await ref.read(connectionProvider.notifier).connect(host, port);

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo - use WHITE for dark theme, BLACK for light theme
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/WHITE_WZ.png'
                        : 'assets/images/BLACK_WZ.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'WIM-Z',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to your robot',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Host input
                  TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Server Address',
                      hintText: 'api.wimzai.com or 192.168.1.50',
                      prefixIcon: Icon(Icons.dns),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter server address';
                      }
                      if (!AppConfig.isValidHost(value)) {
                        return 'Invalid server address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Port input
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter port';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Invalid port number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (connection.hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              connection.errorMessage ?? 'Connection failed',
                              style: const TextStyle(color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Connect button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: connection.isConnecting ? null : _connect,
                      child: connection.isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Help text
                  Text(
                    'Connecting to your WIM-Z robot...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Back to login button
                  TextButton(
                    onPressed: () {
                      context.go('/login');
                    },
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
