import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the auth JWT.
///
/// iOS: Keychain (after_first_unlock, this device only).
/// Android: EncryptedSharedPreferences backed by Keystore.
class SecureTokenStorage {
  static const _keyToken = 'auth_jwt_v1';

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
}
