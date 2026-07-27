import 'dart:convert';

/// Minimal JWT payload decoder. Does NOT verify the signature — that's the
/// server's job. We only need to read public claims (sub, email, exp) for
/// client-side use, e.g. to send the relay-recognised user_id in the
/// session_hello handshake.
///
/// Returns null on any parse failure (malformed token, bad base64, bad JSON).
Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    // Base64url → base64 (replace +/-, _//, add padding)
    payload = payload.replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final decoded = utf8.decode(base64.decode(payload));
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

/// Returns the relay's canonical user_id (e.g. `user_000042`) used for the
/// session_hello handshake validation. Relay tokens carry an explicit
/// `user_id` claim since 2026-07-27 (equal to `sub`); older tokens still in
/// secure storage only have `sub`, so both are read.
String? jwtUserId(String? token) {
  if (token == null) return null;
  final payload = decodeJwtPayload(token);
  return (payload?['user_id'] ?? payload?['sub']) as String?;
}
