import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/auth_api.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import 'missions_provider.dart';

/// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }
}

/// Storage keys
const _keyAuthToken = 'auth_token';
const _keyAuthEmail = 'auth_email';

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadSavedAuth();
  }

  /// Load saved auth from storage
  Future<void> _loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAuthToken);
    final email = prefs.getString(_keyAuthEmail);

    if (token != null) {
      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        email: email,
      );

      // Build 32 fix: Reload dog profiles for restored user session
      // This is critical - without this, dogs load before auth is ready
      // and end up in the "anonymous" bucket
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();
    }
  }

  /// Save auth to storage
  Future<void> _saveAuth(String token, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
    if (email != null) {
      await prefs.setString(_keyAuthEmail, email);
    }
  }

  /// Clear saved auth
  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyAuthEmail);
  }

  /// Register a new account
  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final api = _ref.read(authApiProvider);
      final response = await api.register(email, password);

      await _saveAuth(response.token, email);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.token,
        email: email,
      );

      // Build 32: Reload dog profiles for this user (scoped storage)
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();

      return true;
    } catch (e) {
      String errorMsg = 'Registration failed';
      if (e.toString().contains('409')) {
        errorMsg = 'Email already registered';
      } else if (e.toString().contains('400')) {
        errorMsg = 'Invalid email or password';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }

  /// Login with existing account
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final api = _ref.read(authApiProvider);
      final response = await api.login(email, password);

      await _saveAuth(response.token, email);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.token,
        email: email,
      );

      // Build 32: Reload dog profiles for this user (scoped storage)
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();

      return true;
    } catch (e) {
      String errorMsg = 'Login failed';
      if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMsg = 'Invalid email or password';
      } else if (e.toString().contains('404')) {
        errorMsg = 'Account not found';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }

  /// Logout - clears auth state and resets user-scoped data
  Future<void> logout() async {
    // Disconnect from relay/robot
    await _ref.read(connectionProvider.notifier).disconnect();

    // Clear cloud-synced data like missions
    _ref.read(missionsProvider.notifier).clearState();

    // Build 32 fix: Clear both dog profiles and selected dog
    // This prevents stale dogs from showing when another user logs in
    _ref.read(dogProfilesProvider.notifier).clearState();
    _ref.read(selectedDogProvider.notifier).clearState();

    // Clear stored auth
    await _clearAuth();
    state = const AuthState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Convenience provider for checking if authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Convenience provider for getting the token
final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).token;
});
