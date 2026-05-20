import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for auth credentials — JWT plus, optionally, the password
/// the user opted to remember.
///
/// iOS: Keychain (after_first_unlock, this device only).
/// Android: EncryptedSharedPreferences backed by Keystore.
class SecureTokenStorage {
  static const _keyToken = 'auth_jwt_v1';
  static const _keyPassword = 'auth_pw_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _keyToken);
    } catch (_) {/* best-effort */}
  }

  /// Build 95: opt-in password persistence. User-controlled via "Save
  /// password" checkbox on the login form; the goal is one-tap re-login
  /// when the JWT can't carry the user through (fresh install, JWT expired,
  /// definitive 401 from /validate).
  Future<String?> readPassword() async {
    try {
      return await _storage.read(key: _keyPassword);
    } catch (_) {
      return null;
    }
  }

  Future<void> writePassword(String password) async {
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<void> deletePassword() async {
    try {
      await _storage.delete(key: _keyPassword);
    } catch (_) {/* best-effort */}
  }
}
