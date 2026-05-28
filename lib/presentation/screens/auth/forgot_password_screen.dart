import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Two-stage password recovery screen.
///
/// Stage 1 — collect email, call `POST /api/auth/request-reset`. The relay
/// always responds 200 to avoid leaking which addresses are registered, so
/// we advance to stage 2 on any successful request, not on confirmation of
/// a real account.
///
/// Stage 2 — collect 6-digit code + new password (min 8 chars), call
/// `POST /api/auth/reset-password`. The relay returns a TokenResponse on
/// success (same shape as login) so we drop the user straight onto /home.
///
/// One screen with a setState stage toggle mirrors how login_screen.dart
/// flips between Sign In and Create Account — keeps the back-stack flat
/// and lets the user step back to fix a typo'd email without losing the
/// code they already typed.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Optional pre-fill for the email field — used when navigated from the
  /// login screen so the user doesn't retype an address that's already
  /// sitting in the form above.
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Stage { enterEmail, enterCode }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  _Stage _stage = _Stage.enterEmail;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _codeSentBanner = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    // Point Dio at the relay before the call — the user may have arrived
    // here from a fresh launch where the base URL hasn't been set yet.
    final host = AppConstants.defaultHost;
    const port = AppConstants.defaultPort;
    DioClient.setBaseUrl(AppConfig.baseUrl(host, port));

    final ok = await ref
        .read(authProvider.notifier)
        .requestPasswordReset(_emailController.text.trim());

    if (!mounted) return;
    if (ok) {
      setState(() {
        _stage = _Stage.enterCode;
        _codeSentBanner = true;
      });
    }
  }

  Future<void> _submitReset() async {
    if (!_codeFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    final ok = await ref
        .read(authProvider.notifier)
        .resetPassword(email, code, newPassword);

    if (!mounted) return;
    if (ok) {
      // Match login_screen's post-success path: clear local-mode flag and
      // open the relay WS connection before navigating, so /home doesn't
      // briefly show "Reconnecting…".
      ref.read(settingsProvider.notifier).setLocalModeEnabled(false);
      await ref
          .read(connectionProvider.notifier)
          .connect(AppConstants.defaultHost, AppConstants.defaultPort);
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_stage == _Stage.enterCode) {
              setState(() {
                _stage = _Stage.enterEmail;
                _codeSentBanner = false;
                _codeController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
                ref.read(authProvider.notifier).clearError();
              });
            } else {
              ref.read(authProvider.notifier).clearError();
              context.pop();
            }
          },
        ),
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _stage == _Stage.enterEmail
                ? _buildEmailStage(authState)
                : _buildCodeStage(authState),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStage(AuthState authState) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Forgot your password?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Enter the email on your account and we'll send you a "
            "6-digit code to reset your password.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendCode(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter email';
              if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
              return null;
            },
          ),
          if (authState.errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(message: authState.errorMessage!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _sendCode,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStage(AuthState authState) {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_codeSentBanner)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If that email is registered, a 6-digit code is on the '
                      'way. It expires in 15 minutes.',
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Enter Code & New Password',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text.trim(),
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              prefixIcon: Icon(Icons.pin),
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            maxLength: 6,
            autocorrect: false,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter the code';
              if (v.length != 6) return 'Code is 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              // Relay enforces 8+; mirror that here so the user gets the
              // feedback before paying for a round-trip.
              if (v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            obscureText: _obscureConfirm,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _newPasswordController.text) {
                return "Passwords don't match";
              }
              return null;
            },
          ),
          if (authState.errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(message: authState.errorMessage!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _submitReset,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset Password'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: authState.isLoading ? null : _sendCode,
            child: const Text('Resend code'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
