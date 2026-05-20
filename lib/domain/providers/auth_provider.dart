import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_token_storage.dart';
import '../../data/datasources/auth_api.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import 'missions_provider.dart';
import 'notifications_provider.dart';
import 'settings_provider.dart';
import 'voice_commands_provider.dart';

/// Auth state
class AuthState {
  // Build 94: true until the silent-reauth probe finishes. The splash screen
  // waits on this so we don't flash /login for already-authenticated users.
  final bool bootstrapping;
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
    this.bootstrapping = true,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.email,
    this.userId,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? bootstrapping,
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    String? email,
    String? userId,
    String? errorMessage,
  }) {
    return AuthState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      errorMessage: errorMessage,
    );
  }
}

/// Storage keys. The JWT lives in secure storage (Keychain/Keystore); email
/// and userId are non-secret and stay in SharedPreferences.
const _keyAuthToken = 'auth_token'; // legacy SharedPrefs key — read once for migration
const _keyAuthEmail = 'auth_email';
const _keyAuthUserId = 'auth_user_id';

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final SecureTokenStorage _secureStorage = SecureTokenStorage();

  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadSavedAuth();
  }

  /// Load saved auth from storage and silent-reauth via /api/auth/validate.
  ///
  /// Build 94: JWT now lives in flutter_secure_storage. On first launch after
  /// upgrade we migrate any token still in SharedPreferences. We treat the
  /// token as valid only if /validate returns 200; an expired/revoked token
  /// is cleared so the user is shown the login screen instead of failing
  /// downstream API calls.
  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyAuthEmail);
      final userId = prefs.getString(_keyAuthUserId);

      String? token = await _secureStorage.readToken();

      // One-time migration: if the legacy SharedPrefs token exists, copy it
      // into secure storage and remove the plaintext copy.
      if (token == null) {
        final legacyToken = prefs.getString(_keyAuthToken);
        if (legacyToken != null && legacyToken.isNotEmpty) {
          await _secureStorage.writeToken(legacyToken);
          await prefs.remove(_keyAuthToken);
          token = legacyToken;
        }
      } else {
        // Token already in secure storage — clean up any stale SharedPrefs
        // copy left behind by a previous build.
        await prefs.remove(_keyAuthToken);
      }

      if (token == null || token.isEmpty) {
        state = state.copyWith(bootstrapping: false);
        return;
      }

      // Silent re-auth: only trust the token if the relay still accepts it.
      final api = _ref.read(authApiProvider);
      final ok = await api.validateToken(token);

      if (!ok) {
        await _secureStorage.deleteToken();
        await prefs.remove(_keyAuthEmail);
        await prefs.remove(_keyAuthUserId);
        state = state.copyWith(bootstrapping: false);
        return;
      }

      // Cloud user restoring session — ensure local mode flag is off
      // so Manage Devices shows in settings (Build 83 fix)
      _ref.read(settingsProvider.notifier).setLocalModeEnabled(false);

      state = state.copyWith(
        bootstrapping: false,
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
    } catch (e) {
      print('Auth: silent re-auth failed: $e');
      state = state.copyWith(bootstrapping: false);
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

  /// Save auth to storage. JWT → secure storage; email/userId → SharedPrefs.
  Future<void> _saveAuth(String token, String? email, String? userId) async {
    await _secureStorage.writeToken(token);
    final prefs = await SharedPreferences.getInstance();
    if (email != null) {
      await prefs.setString(_keyAuthEmail, email);
    }
    if (userId != null) {
      await prefs.setString(_keyAuthUserId, userId);
    } else {
      await prefs.remove(_keyAuthUserId);
    }
  }

  /// Clear saved auth from both stores.
  Future<void> _clearAuth() async {
    await _secureStorage.deleteToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken); // legacy
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
        bootstrapping: false,
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
        bootstrapping: false,
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
    state = const AuthState(bootstrapping: false);
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
