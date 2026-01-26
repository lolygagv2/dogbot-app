import 'dart:convert';

import '../network/websocket_client.dart';

// Reference to dart:core print to avoid shadowing
final void Function(Object?) _consolePrint = print;

/// Remote logger that sends debug logs to relay server via WebSocket
/// Logs go to BOTH local console AND relay server for remote debugging.
class RemoteLogger {
  static bool enabled = true;
  static final List<String> _pendingLogs = [];
  static const int _maxPendingLogs = 100;

  /// Log a message - sends to console AND relay server
  static void log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final fullMessage = '[$tag] $message';

    // Always print to local console (use _consolePrint to avoid recursion)
    _consolePrint(fullMessage);

    if (!enabled) return;

    // Send to relay server
    _sendLog(tag, message, timestamp);
  }

  /// Log with automatic tag extraction from message prefix
  /// e.g. rprint('PTT: Recording started') → tag='PTT', message='Recording started'
  static void rprint(String message) {
    final colonIndex = message.indexOf(': ');
    if (colonIndex > 0 && colonIndex < 30) {
      final tag = message.substring(0, colonIndex);
      final msg = message.substring(colonIndex + 2);
      log(tag, msg);
    } else {
      log('App', message);
    }
  }

  static void _sendLog(String tag, String message, String timestamp) {
    try {
      final wsClient = WebSocketClient.instance;

      if (wsClient.state != WsConnectionState.connected) {
        // Queue log if not connected (up to max limit)
        if (_pendingLogs.length < _maxPendingLogs) {
          _pendingLogs.add(jsonEncode({
            'type': 'debug_log',
            'tag': tag,
            'message': message,
            'timestamp': timestamp,
          }));
        }
        return;
      }

      // Send log to relay server
      wsClient.send({
        'type': 'debug_log',
        'tag': tag,
        'message': message,
        'timestamp': timestamp,
      });
    } catch (e) {
      // Silently fail - don't want logging to break the app
    }
  }

  static void _flushPendingLogs() {
    if (_pendingLogs.isEmpty) return;

    try {
      final wsClient = WebSocketClient.instance;
      if (wsClient.state != WsConnectionState.connected) return;

      for (final logJson in _pendingLogs) {
        final decoded = jsonDecode(logJson) as Map<String, dynamic>;
        wsClient.send(decoded);
      }
      _pendingLogs.clear();
    } catch (e) {
      // Silently fail
    }
  }

  /// Call when WebSocket connects to flush pending logs
  static void onConnected() {
    _flushPendingLogs();
  }
}

/// Shorthand for tagged logging: rlog('PTT', 'Recording started')
void rlog(String tag, String message) => RemoteLogger.log(tag, message);

/// Shorthand that mimics print() but sends to relay too
void rprint(String message) => RemoteLogger.rprint(message);
