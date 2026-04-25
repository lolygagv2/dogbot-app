import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Per-app-launch session id for the WS handshake (B1).
///
/// Regenerated on every fresh `connect()` so the relay can supersede the prior
/// session for the same (user, device) pair, and so the robot can tear down
/// any stale PeerConnection when a new session starts.
///
/// Read access via [sessionIdProvider] (Riverpod) or [SessionId.current].
class SessionId {
  static const _uuid = Uuid();
  static String _current = _uuid.v4();

  /// The current session id. Stable across the lifetime of one connect().
  static String get current => _current;

  /// Generate a new session id and return it. Called by ConnectionNotifier
  /// before opening a new WebSocket.
  static String regenerate() {
    _current = _uuid.v4();
    return _current;
  }
}

/// Riverpod accessor — returns the current session id.
/// Note: this is not reactive (changes don't notify watchers); read it on demand.
final sessionIdProvider = Provider<String>((ref) => SessionId.current);
