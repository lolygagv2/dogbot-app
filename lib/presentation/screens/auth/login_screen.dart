import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Login/Welcome screen for WIM-Z with 3 options:
/// 1. Login — cloud relay with authentication
/// 2. Connect to Robot — direct AP connection at 192.168.4.1 (no internet)
/// 3. Demo Mode — simulated app demo
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _showLoginForm = false;
  bool _isConnectingLocal = false;
  String? _localError;

  static const _keyLastEmail = 'last_login_email';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_keyLastEmail);
    if (mounted && savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Login flow — authenticate then connect to relay
  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final host = AppConstants.defaultHost;
    const port = AppConstants.defaultPort;

    final baseUrl = AppConfig.baseUrl(host, port);
    DioClient.setBaseUrl(baseUrl);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool success;
    if (_isLogin) {
      success = await ref.read(authProvider.notifier).login(email, password);
    } else {
      success = await ref.read(authProvider.notifier).register(email, password);
    }

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastEmail, email);

      ref.read(settingsProvider.notifier).setLocalModeEnabled(false);
      await ref.read(connectionProvider.notifier).connect(host, port);
      if (mounted) context.go('/home');
    }
  }

  /// Connect to Robot — direct AP connection at 192.168.4.1, no auth, no relay
  Future<void> _connectToRobot() async {
    setState(() {
      _isConnectingLocal = true;
      _localError = null;
    });

    ref.read(settingsProvider.notifier).setLocalModeEnabled(true);

    try {
      final success = await ref
          .read(localConnectionProvider.notifier)
          .connectViaHotspot()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);

      if (mounted) {
        if (success) {
          ref.read(connectionProvider.notifier).setLocalConnected();
          context.go('/home');
        } else {
          setState(() {
            _isConnectingLocal = false;
            _localError =
                'Could not connect to robot.\n'
                'Make sure you\'re connected to the WIMZ WiFi network.\n'
                'For other networks, use Settings after connecting.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectingLocal = false;
          _localError = 'Connection failed. Check WiFi and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/BLACK_WZ.png'
                      : 'assets/images/WHITE_WZ.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 16),
                Text(
                  'WIM-Z',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watchful Intelligent Mobile Zen',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 48),

                // === Main 3 buttons ===
                if (!_showLoginForm) ...[
                  // 1. Login
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _showLoginForm = true),
                      icon: const Icon(Icons.cloud),
                      label: const Text('Login',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    child: Text('Cloud connection (requires internet)',
                        style: TextStyle(fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  ),

                  // 2. Connect to Robot
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isConnectingLocal ? null : _connectToRobot,
                      icon: _isConnectingLocal
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi),
                      label: Text(
                        _isConnectingLocal ? 'Connecting...' : 'Connect to Robot',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Text('Direct connection via WIMZ WiFi hotspot',
                        style: TextStyle(fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  ),

                  // Error message
                  if (_localError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_localError!,
                              style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                        ],
                      ),
                    ),

                  // 3. Demo Mode
                  TextButton(
                    onPressed: () => context.go('/demo'),
                    child: const Text('Demo Mode'),
                  ),
                ],

                // === Login form ===
                if (_showLoginForm)
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() => _showLoginForm = false);
                                ref.read(authProvider.notifier).clearError();
                              },
                            ),
                            Text(_isLogin ? 'Sign In' : 'Create Account',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email', hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.email)),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter email';
                            if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter password';
                            if (!_isLogin && v.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(authState.errorMessage!,
                                  style: const TextStyle(color: AppTheme.error))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submitLogin,
                            child: authState.isLoading
                                ? const SizedBox(width: 24, height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_isLogin ? 'Sign In' : 'Create Account'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                            ref.read(authProvider.notifier).clearError();
                          },
                          child: Text(_isLogin
                              ? "Don't have an account? Sign up"
                              : 'Already have an account? Sign in'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
