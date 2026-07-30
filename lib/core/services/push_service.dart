import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import '../utils/conn_trace.dart';

/// Singleton wrapper around Firebase Messaging (APNs/FCM device push).
///
/// The relay — not this app — composes and sends the pushes; this service
/// only obtains the device token so the relay knows where to send. Delivery
/// works while the app is suspended or killed because iOS/Android display
/// FCM notification messages at the OS level.
///
/// Soft-disabled until `flutterfire configure` replaces the placeholder
/// firebase_options.dart: init() reports false, everything else no-ops, and
/// the app runs without a Firebase project (also on desktop platforms).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  bool get isAvailable => _initialized;

  /// Initialize Firebase and request notification permission.
  /// Returns false (and stays disabled) on placeholder config, unsupported
  /// platform, or any init failure — never throws.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey == 'PLACEHOLDER') {
        connTrace('push-disabled', 'firebase_options.dart is placeholder — run flutterfire configure');
        return false;
      }
      await Firebase.initializeApp(options: options);
      final settings = await FirebaseMessaging.instance.requestPermission();
      connTrace('push-permission', settings.authorizationStatus.name);
      _initialized = true;
      return true;
    } catch (e) {
      connTrace('push-init-error', '$e');
      return false;
    }
  }

  /// Current FCM device token, or null when unavailable.
  Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      connTrace('push-token-error', '$e');
      return null;
    }
  }

  /// Fires when FCM rotates the device token — re-register with the relay.
  /// Only subscribe after init() returned true.
  Stream<String> get tokenRefreshStream =>
      FirebaseMessaging.instance.onTokenRefresh;
}
