import 'dart:io';

import 'package:flutter/services.dart';

/// Pins the app's network traffic to the WiFi interface while in local-AP mode.
///
/// Problem (Android-only): when the phone joins the WIMZ- access point, that
/// network has no upstream internet. Android notices the dead end and, on many
/// OEMs/versions, routes the app's sockets back over cellular — so REST/WS/MJPEG
/// to the robot silently never arrive and the app looks like it's "connecting
/// forever". Calling [bindToWifi] forces every socket in the process onto the
/// WiFi network (native ConnectivityManager.bindProcessToNetwork) until
/// [unbind] is called.
///
/// iOS routes to the joined WiFi automatically and has no equivalent API, so
/// every method here is a no-op on non-Android platforms.
class WifiBinder {
  static const MethodChannel _channel =
      MethodChannel('com.wimzai.app/wifi_bind');

  /// Binds the process to the currently-connected WiFi network.
  /// Returns true if the bind succeeded. False on non-Android, on timeout, or
  /// if WiFi isn't connected.
  static Future<bool> bindToWifi() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('bindToWifi');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Releases the WiFi binding so the process returns to normal routing
  /// (e.g. when switching back to relay/remote mode or disconnecting).
  static Future<void> unbind() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('unbind');
    } catch (_) {
      // Best-effort cleanup — nothing to do if the channel isn't there.
    }
  }
}
