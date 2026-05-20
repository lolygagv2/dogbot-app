import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/providers/auth_provider.dart';

/// Shown at app launch while AuthNotifier validates any stored JWT.
/// Routes to /home if silent re-auth succeeds, /login otherwise.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!next.bootstrapping) {
        final target = next.isAuthenticated ? '/home' : '/login';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(target);
        });
      }
    });

    final auth = ref.read(authProvider);
    if (!auth.bootstrapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(auth.isAuthenticated ? '/home' : '/login');
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/BLACK_WZ.png'
                    : 'assets/images/WHITE_WZ.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
