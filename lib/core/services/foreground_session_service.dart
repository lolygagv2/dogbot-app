import 'dart:io';

import 'package:flutter/services.dart';

/// Starts/stops the Android foreground service that keeps the process resident
/// during an active live session (drive screen / WebRTC / two-way audio).
///
/// Without it, Android OEM battery optimizers kill the backgrounded app and
/// tear down the WebSocket/WebRTC link and audio threads. iOS uses background
/// modes instead, so this no-ops on non-Android platforms.
///
/// Idempotent: repeated start()/stop() calls are coalesced via [_running].
class ForegroundSessionService {
  static const MethodChannel _channel =
      MethodChannel('com.wimzai.app/foreground');
  static bool _running = false;

  /// Begin keeping the process alive. Call when a live session starts (while
  /// the app is foregrounded — drive screen open).
  static Future<void> start() async {
    if (!Platform.isAndroid || _running) return;
    try {
      await _channel.invokeMethod<void>('start');
      _running = true;
    } catch (_) {
      // Best-effort — a failed start just means we fall back to OS defaults.
    }
  }

  /// Stop keeping the process alive. Call when the session ends.
  static Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // ignore
    }
    _running = false;
  }
}
