import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/push_service.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/notification_event.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

/// Push registration coordinator.
///
/// Keeps the relay's view of this device current: registers the FCM token
/// after login, re-registers when the token rotates or the per-type "+ Push"
/// preferences change (the relay only sends what this device asked for), and
/// unregisters on logout. Instantiated once at app startup (app.dart) like
/// voiceCommandsAutoSyncProvider.
final pushSyncProvider = Provider<PushSync>((ref) {
  final sync = PushSync(ref);
  ref.onDispose(sync.dispose);

  ref.listen<String?>(
    authProvider.select((a) => a.token),
    (prev, next) => sync.onAuthChanged(prev, next),
  );
  ref.listen(settingsProvider, (prev, next) {
    if (prev == null) return;
    final changed = prev.notificationsEnabled != next.notificationsEnabled ||
        prev.notificationChannels != next.notificationChannels;
    if (changed) sync.schedulePreferenceSync();
  });

  // Auth may already be restored by the time we're instantiated.
  final existing = ref.read(authProvider).token;
  if (existing != null) sync.onAuthChanged(null, existing);

  return sync;
});

class PushSync {
  final Ref _ref;
  Timer? _debounce;
  StreamSubscription<String>? _refreshSub;
  String? _registeredJwt;
  String? _registeredDeviceToken;

  PushSync(this._ref);

  /// Relay event-preference payload: names of every type routed
  /// "In-app + Push", or empty when the master switch is off.
  List<String> _enabledTypes() {
    final settings = _ref.read(settingsProvider);
    if (!settings.notificationsEnabled) return const [];
    return NotificationEventType.values
        .where((t) =>
            settings.channelFor(t) == NotificationChannel.inAppAndPush)
        .map((t) => t.name)
        .toList();
  }

  Future<void> onAuthChanged(String? prevJwt, String? jwt) async {
    if (jwt == null) {
      // Logged out — best-effort unregister under the session that
      // registered (it may already be revoked server-side; that's fine,
      // the relay also prunes tokens on FCM 404/410).
      final deviceToken = _registeredDeviceToken;
      final registeredJwt = _registeredJwt ?? prevJwt;
      _registeredDeviceToken = null;
      _registeredJwt = null;
      if (deviceToken != null && registeredJwt != null) {
        unawaited(_ref
            .read(robotApiProvider)
            .unregisterPushDevice(token: registeredJwt, deviceToken: deviceToken));
        connTrace('push-unregister', 'sent on logout');
      }
      return;
    }
    if (jwt == _registeredJwt) return;
    await register();
  }

  /// Idempotent: init Firebase (no-op if placeholder config), fetch the FCM
  /// token, and upsert (token, platform, enabled types) at the relay.
  Future<void> register() async {
    final jwt = _ref.read(authProvider).token;
    if (jwt == null) return;
    if (!await PushService.instance.init()) return;

    final deviceToken = await PushService.instance.getToken();
    if (deviceToken == null) return;

    _refreshSub ??= PushService.instance.tokenRefreshStream.listen((_) {
      _registeredJwt = null; // force re-register with the fresh token
      unawaited(register());
    });

    final enabled = _enabledTypes();
    final ok = await _ref.read(robotApiProvider).registerPushDevice(
          token: jwt,
          deviceToken: deviceToken,
          platform: Platform.isIOS ? 'ios' : 'android',
          enabledTypes: enabled,
        );
    if (ok) {
      _registeredJwt = jwt;
      _registeredDeviceToken = deviceToken;
    }
    connTrace('push-register', 'ok=$ok types=${enabled.length}');
  }

  /// Debounced re-register after notification preference changes so a burst
  /// of segmented-button taps becomes one relay call.
  void schedulePreferenceSync() {
    if (_ref.read(authProvider).token == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _registeredJwt = null; // preferences changed → payload changed
      unawaited(register());
    });
  }

  void dispose() {
    _debounce?.cancel();
    _refreshSub?.cancel();
  }
}
