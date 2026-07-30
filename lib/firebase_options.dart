import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// PLACEHOLDER Firebase config — push notifications stay soft-disabled until
/// this file is regenerated with real values:
///
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// That command overwrites this file in place (same class/API, real keys).
/// PushService detects the 'PLACEHOLDER' apiKey and skips Firebase init, so
/// the app builds and runs fine before the Firebase project exists.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push is not configured for WIM-Z.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'Push is not supported on $defaultTargetPlatform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    iosBundleId: 'PLACEHOLDER',
  );
}
