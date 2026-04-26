import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/auth_api.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import 'missions_provider.dart';
import 'notifications_provider.dart';
import 'settings_provider.dart';
import 'voice_commands_provider.dart';

/// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;
  final String? email;
  // Build 88: persist relay's user_id from auth response. Used for the WS
  // session_hello handshake — the relay validates this against the JWT
  // subject, so it must match what the relay set.
  final String? userId;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.email,
    this.userId,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    String? email,
    String? userId,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      errorMessage: errorMessage,
    );
  }
}

/// Storage keys
const _keyAuthToken = 'auth_token';
const _keyAuthEmail = 'auth_email';
const _keyAuthUserId = 'auth_user_id';

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
    final userId = prefs.getString(_keyAuthUserId);

    if (token != null) {
      // Cloud user restoring session — ensure local mode flag is off
      // so Manage Devices shows in settings (Build 83 fix)
      _ref.read(settingsProvider.notifier).setLocalModeEnabled(false);

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        email: email,
        userId: userId,
      );

      // Build 32 fix: Reload dog profiles for restored user session
      // This is critical - without this, dogs load before auth is ready
      // and end up in the "anonymous" bucket
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();

      // A1/A2/A3: hydrate cross-device data from relay. Best-effort —
      // failures (offline, 401, etc.) shouldn't block auth restoration.
      _hydrateAllFromRelay(scenario: 'restore');
    }
  }

  /// A1/A2/A3: chain hydration of dog profiles, voice commands, and activity.
  /// Runs in the background; never blocks the auth flow on failure.
  Future<void> _hydrateAllFromRelay({required String scenario}) async {
    try {
      await _ref.read(dogProfilesProvider.notifier).hydrateFromRelay();
    } catch (e) {
      print('Auth: hydrate dogs on $scenario failed: $e');
    }
    try {
      final dogs = _ref.read(dogProfilesProvider);
      for (final dog in dogs) {
        await _ref.read(voiceCommandsProvider(dog.id).notifier).hydrateFromRelay();
      }
    } catch (e) {
      print('Auth: hydrate voice commands on $scenario failed: $e');
    }
    try {
      await _ref.read(notificationsProvider.notifier).hydrateFromRelay();
    } catch (e) {
      print('Auth: hydrate activity on $scenario failed: $e');
    }
  }

  /// Save auth to storage
  Future<void> _saveAuth(String token, String? email, String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
    if (email != null) {
      await prefs.setString(_keyAuthEmail, email);
    }
    if (userId != null) {
      await prefs.setString(_keyAuthUserId, userId);
    } else {
      await prefs.remove(_keyAuthUserId);
    }
  }

  /// Clear saved auth
  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyAuthEmail);
    await prefs.remove(_keyAuthUserId);
  }

  /// Register a new account
  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final api = _ref.read(authApiProvider);
      final response = await api.register(email, password);

      await _saveAuth(response.token, email, response.userId);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.token,
        email: email,
        userId: response.userId,
      );

      // Build 32: Reload dog profiles for this user (scoped storage)
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();

      // A1/A2/A3: hydrate from relay so a fresh install/new device restores data.
      _hydrateAllFromRelay(scenario: 'register');

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

      await _saveAuth(response.token, email, response.userId);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.token,
        email: email,
        userId: response.userId,
      );

      // Build 32: Reload dog profiles for this user (scoped storage)
      await _ref.read(dogProfilesProvider.notifier).reloadForCurrentUser();

      // A1/A2/A3: hydrate from relay so a fresh install/new device restores data.
      _hydrateAllFromRelay(scenario: 'login');

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
