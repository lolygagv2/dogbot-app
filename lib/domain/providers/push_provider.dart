import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/push_routes.dart';
import '../../core/services/push_service.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/notification_event.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'treat_schedule_provider.dart';

/// Route a tapped push wants opened. Set by [PushSync] (background tap or
/// cold-start launch), consumed by the app shell once the router is on an
/// authenticated route (app.dart) — the splash's own `/home` navigation
/// would otherwise race it.
final pushNavigationTargetProvider = StateProvider<String?>((ref) => null);

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
  StreamSubscription<RemoteMessage>? _tapSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _initialMessageChecked = false;
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
    _tapSub ??= PushService.instance.onMessageOpenedApp.listen(_onTapped);
    _foregroundSub ??=
        PushService.instance.onForegroundMessage.listen(_onForeground);
    if (!_initialMessageChecked) {
      _initialMessageChecked = true;
      final initial = await PushService.instance.initialMessage();
      if (initial != null) _onTapped(initial);
    }

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

  /// Background / cold-start tap: hand the route to the shell.
  void _onTapped(RemoteMessage m) {
    final route = pushRouteFor(m.data);
    connTrace('push-tap', 'kind=${m.data['kind']} type=${m.data['type']} → $route');
    if (route == null) return;
    _ref.read(pushNavigationTargetProvider.notifier).state = route;
    _refreshForPush(m.data);
  }

  /// Foreground arrival: no navigation, but refresh what the push is about.
  void _onForeground(RemoteMessage m) {
    connTrace('push-foreground', 'kind=${m.data['kind']} type=${m.data['type']}');
    _refreshForPush(m.data);
  }

  void _refreshForPush(Map<String, dynamic> data) {
    if (data['kind']?.toString() == kPushKindTreatLimitRaised) {
      // Brief 2026-11-09 §5: an assistant raised the cap — re-read the
      // relay value so Settings shows the toggle/slider as they now are.
      _ref
          .read(treatScheduleProvider.notifier)
          .scheduleResync(after: const Duration(milliseconds: 300));
    }
  }

  void dispose() {
    _debounce?.cancel();
    _refreshSub?.cancel();
    _tapSub?.cancel();
    _foregroundSub?.cancel();
  }
}
