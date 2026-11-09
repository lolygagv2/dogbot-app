import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/local_connection_service.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
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
  final _secureStorage = SecureTokenStorage();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _showLoginForm = false;
  bool _isConnectingLocal = false;
  bool _savePassword = true; // Build 95: opt-in (default on) password persistence
  String? _localError;

  static const _keyLastEmail = 'last_login_email';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_keyLastEmail);
    final savedPassword = await _secureStorage.readPassword();
    if (!mounted) return;
    setState(() {
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
      if (savedPassword != null && savedPassword.isNotEmpty) {
        _passwordController.text = savedPassword;
      }
      // If there's no stored password the user is on a fresh install or
      // previously opted out — uncheck so we don't surprise-save.
      _savePassword = savedPassword != null && savedPassword.isNotEmpty
          ? true
          : _savePassword;
    });
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

    const host = AppConstants.defaultHost;
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

      // Build 95: honor the Save Password toggle. Stored in secure storage
      // (Keychain/Keystore) so we can pre-fill on the next visit to /login.
      if (_savePassword) {
        await _secureStorage.writePassword(password);
      } else {
        await _secureStorage.deletePassword();
      }

      // Build 123: relay connect + local-mode reset now happen inside
      // authProvider.login()/register() (see _connectRelay) so they can't be
      // skipped if this screen is torn down or login() unwinds post-auth.
      if (mounted) context.go('/home');
    }
  }

  /// Connect to Robot — direct AP connection at 192.168.4.1, no auth, no relay
  Future<void> _connectToRobot() async {
    setState(() {
      _isConnectingLocal = true;
      _localError = null;
    });

    await ref.read(settingsProvider.notifier).setLocalModeEnabled(true);

    try {
      // A-DISCOVER: race the AP address and the last IP that worked instead
      // of only trying 192.168.4.1 — finds a robot that joined home WiFi too.
      final success = await ref
          .read(localConnectionProvider.notifier)
          .connectAuto()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (mounted) {
        if (success) {
          final local = ref.read(localConnectionProvider);
          ref.read(connectionProvider.notifier).setLocalConnected(
              local.robotIp ?? '192.168.4.1', local.port);
          context.go('/home');
        } else {
          setState(() {
            _isConnectingLocal = false;
            _localError = context.l10n.loginLocalConnectFailed;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectingLocal = false;
          _localError = context.l10n.loginConnectionFailedCheckWifi;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo — the product figurehead photo (black ground, square)
                ClipRRect(
                  borderRadius: BorderRadius.circular(WimzTheme.radiusLarge),
                  child: Image.asset(
                    'assets/images/wimz_figurehead.jpg',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
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
                  context.l10n.loginTagline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                // Build 99: shown when the user is bounced here by an expired
                // session (WS 4001 or REST 401) rather than an explicit Sign
                // Out tap. Explains *why* they were kicked.
                if (authState.loginNotice != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    // Informational notice: a flat brand card.
                    decoration: BoxDecoration(
                      color: w.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: w.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: cs.onSurface, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authState.loginNotice!,
                            style: TextStyle(
                                color: cs.onSurface, fontSize: 13),
                          ),
                        ),
                        InkWell(
                          onTap: () => ref
                              .read(authProvider.notifier)
                              .clearLoginNotice(),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                color: w.inkMuted, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      label: Text(context.l10n.loginButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      // Login's ONE gold element: the Sign-in hero CTA.
                      // (The form's submit below takes it over when the form
                      // is open — the two are never on screen together.)
                      style: WimzTheme.goldButtonStyle(context).copyWith(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    child: Text(context.l10n.loginCloudHint,
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
                          ? SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                          : const Icon(Icons.wifi),
                      label: Text(
                        _isConnectingLocal ? context.l10n.connecting : context.l10n.loginConnectToRobot,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Text(context.l10n.loginDirectHint,
                        style: TextStyle(fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  ),

                  // Error message
                  if (_localError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: cs.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_localError!,
                              style: TextStyle(color: cs.error, fontSize: 13))),
                        ],
                      ),
                    ),

                  // 3. Demo Mode
                  TextButton(
                    onPressed: () => context.go('/demo'),
                    child: Text(context.l10n.loginDemoMode),
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
                            Text(_isLogin ? context.l10n.loginSignIn : context.l10n.loginCreateAccount,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: context.l10n.loginEmailLabel, hintText: 'you@example.com',
                            prefixIcon: const Icon(Icons.email)),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          validator: (v) {
                            if (v == null || v.isEmpty) return context.l10n.loginEnterEmail;
                            if (!v.contains('@') || !v.contains('.')) return context.l10n.loginInvalidEmail;
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: context.l10n.loginPasswordLabel,
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) return context.l10n.loginEnterPassword;
                            if (!_isLogin && v.length < 6) return context.l10n.loginMin6Chars;
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        // Build 95: opt-in password persistence. Default ON so
                        // the second visit to /login is one-tap.
                        Row(
                          children: [
                            Checkbox(
                              value: _savePassword,
                              onChanged: (v) =>
                                  setState(() => _savePassword = v ?? false),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _savePassword = !_savePassword),
                              child: Text(context.l10n.loginSavePassword),
                            ),
                            const Spacer(),
                            if (_isLogin)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref
                                      .read(authProvider.notifier)
                                      .clearError();
                                  context.push(
                                    '/forgot-password',
                                    extra: {
                                      'email': _emailController.text.trim(),
                                    },
                                  );
                                },
                                child: Text(context.l10n.loginForgotPassword),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Icon(Icons.error_outline, color: cs.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(authState.errorMessage!,
                                  style: TextStyle(color: cs.error))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submitLogin,
                            // The form's Sign in / Create account submit is the
                            // gold hero CTA while the form is open.
                            style: WimzTheme.goldButtonStyle(context),
                            child: authState.isLoading
                                ? const SizedBox(width: 24, height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_isLogin ? context.l10n.loginSignIn : context.l10n.loginCreateAccount),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                            ref.read(authProvider.notifier).clearError();
                          },
                          child: Text(_isLogin
                              ? context.l10n.loginNoAccountSignUp
                              : context.l10n.loginHaveAccountSignIn),
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
