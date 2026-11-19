import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/dog_profile.dart';
import '../../data/models/robot_state.dart';
import 'auth_provider.dart';
import 'device_provider.dart';
import 'dog_profiles_provider.dart';
import 'settings_provider.dart';

/// ROBOT-STATE v2: the relay-owned state record of the TARGET robot, or
/// null until one has been received (always null on the local-AP socket
/// unless the robot sends the frame itself).
///
/// Fed by the WS `robot_state` frame (E2 — every change and on connect)
/// and `GET /api/devices/{device_id}/state` (H1 — at start-up and on a
/// robot switch). Nothing here is predicted locally.
final robotStateProvider =
    StateNotifierProvider<RobotStateNotifier, RobotState?>((ref) {
  return RobotStateNotifier(ref);
});

/// True on the local / AP link (phone talks straight to the robot, no
/// relay). ROBOT-STATE v2 does not apply there: the selected dog is the
/// app's own selection, sent with the existing select_dog frame.
final isLocalRobotLinkProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).localModeEnabled ||
      ref.watch(localConnectionProvider).isConnected;
});

/// The dog to PRESENT as the selected dog.
///
/// "No dog selected" (null while dogs exist) is shown in exactly one
/// case: cloud mode, AND a `robot_state` has been received, AND its
/// `selected_dog_id` is null (or names no dog this app knows). The
/// per-dog screens keep showing data for [selectedDogProvider].
///
/// In local / AP mode, and whenever no `robot_state` has arrived, it is
/// the app's own selection — the absence of a record is never "no dog".
final shownSelectedDogProvider = Provider<DogProfile?>((ref) {
  if (ref.watch(isLocalRobotLinkProvider)) {
    return ref.watch(selectedDogProvider);
  }
  final rs = ref.watch(robotStateProvider);
  if (rs == null) return ref.watch(selectedDogProvider);
  final id = rs.selectedDogId;
  if (id == null) return null;
  for (final p in ref.watch(dogProfilesProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

/// The dog selector's own tap, while H2 is on its way: the tapped dog is
/// shown as pending and the selected dog only changes with the answer.
class DogSelectionStatus {
  final String? pendingDogId;

  /// Set when the last H2 failed (nothing changed, nothing retried).
  final DateTime? failedAt;
  const DogSelectionStatus({this.pendingDogId, this.failedAt});
  bool get isPending => pendingDogId != null;
}

final dogSelectionStatusProvider =
    StateProvider<DogSelectionStatus>((ref) => const DogSelectionStatus());

class RobotStateNotifier extends StateNotifier<RobotState?> {
  final Ref _ref;
  StreamSubscription<WsEvent>? _wsSub;
  StreamSubscription<WsConnectionState>? _wsStateSub;
  WsConnectionState _lastWsState = WsConnectionState.disconnected;

  /// H2 calls in flight: while the user's own selection is on its way the
  /// relay's (older) value must not be adopted back over it.
  int _selectInFlight = 0;

  RobotStateNotifier(this._ref) : super(null) {
    _wsSub = _ref.read(websocketClientProvider).eventStream.listen((e) {
      if (e.type != 'robot_state') return;
      final rs = RobotState.tryParse(e.data);
      if (rs == null) {
        connTrace('robot-state-bad', '${e.data}');
        return;
      }
      _apply(rs, 'ws');
    });
    _ref.listen<String>(deviceIdProvider, (prev, next) {
      if (prev == next) return;
      state = null;
      unawaited(refresh());
    });
    // H1 again on every (re)connect of the socket: frames sent while the
    // app was away are not replayed.
    final ws = _ref.read(websocketClientProvider);
    _wsStateSub = ws.stateStream.listen((next) {
      if (next == WsConnectionState.connected &&
          _lastWsState != WsConnectionState.connected) {
        unawaited(refresh());
      }
      _lastWsState = next;
    });
    // Profiles can load after the first state record.
    _ref.listen(dogProfilesProvider, (_, __) => _reconcileSelectedDog());
    unawaited(refresh());
  }

  /// True on the local-AP socket (phone talks straight to the robot, no
  /// relay): there is no relay record, and that path is unchanged by v2.
  bool get isLocalMode => _ref.read(isLocalRobotLinkProvider);

  Options? get _auth {
    final token = _ref.read(authTokenProvider);
    if (token == null) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  void _apply(RobotState rs, String via) {
    final target = _ref.read(websocketClientProvider).targetDeviceId;
    if (rs.deviceId != null && target != null && rs.deviceId != target) {
      return; // another robot's record
    }
    final cur = state;
    if (cur != null &&
        cur.deviceId == rs.deviceId &&
        rs.stateVersion < cur.stateVersion) {
      final older = rs.updatedAt == null ||
          cur.updatedAt == null ||
          !rs.updatedAt!.isAfter(cur.updatedAt!);
      if (older) {
        connTrace('robot-state-stale',
            'via=$via v${rs.stateVersion} < v${cur.stateVersion}');
        return;
      }
    }
    connTrace('robot-state', 'via=$via $rs');
    state = rs;
    _reconcileSelectedDog();
  }

  /// H1. Relay mode only; errors are traced, never thrown.
  Future<void> refresh() async {
    if (isLocalMode) return;
    final auth = _auth;
    if (auth == null) return;
    if (!_ref.read(hasSelectedDeviceProvider)) return;
    final deviceId = _ref.read(deviceIdProvider);
    final path = ApiEndpoints.deviceState(deviceId);
    try {
      final r = await _ref.read(dioClientProvider).get(path, options: auth);
      if (!mounted) return;
      final d = r.data;
      final rs = d is Map ? RobotState.tryParse(d) : null;
      if (rs == null) {
        connTrace('robot-state-http', 'GET $path → unusable body');
        return;
      }
      _apply(rs, 'GET');
    } on DioException catch (e) {
      connTrace('robot-state-http',
          'GET $path → HTTP ${e.response?.statusCode} ${e.message ?? ''}');
    } catch (e) {
      connTrace('robot-state-http', 'GET $path → $e');
    }
  }

  /// The user picked [dogId] in the app: H2, and nothing else. The relay
  /// stores it and tells the robot (now, or once on its next connect).
  ///
  /// Returns null when there is no relay record to write — local-AP mode,
  /// not signed in, or no robot paired — so the caller selects locally.
  /// Otherwise true (the answer was applied; the selected dog now follows
  /// the returned record) or false (failed; nothing changed, no retry).
  Future<bool?> selectDogViaRelay(String? dogId) async {
    if (isLocalMode) return null;
    final auth = _auth;
    if (auth == null || !_ref.read(hasSelectedDeviceProvider)) return null;
    final deviceId = _ref.read(deviceIdProvider);
    final path = ApiEndpoints.deviceSelectedDog(deviceId);
    final status = _ref.read(dogSelectionStatusProvider.notifier);
    final sw = Stopwatch()..start();
    _selectInFlight++;
    status.state = DogSelectionStatus(pendingDogId: dogId);
    try {
      final r = await _ref
          .read(dioClientProvider)
          .post(path, data: {'dog_id': dogId}, options: auth);
      final d = r.data;
      final rs = d is Map ? RobotState.tryParse(d) : null;
      connTrace('select-dog',
          'POST $path dog=$dogId → HTTP ${r.statusCode} in ${sw.elapsedMilliseconds}ms '
          'sel=${rs?.selectedDogId} applied=${rs?.selectedDogApplied} online=${rs?.robotOnline}');
      _selectInFlight--;
      if (!mounted) return true;
      status.state = const DogSelectionStatus();
      if (rs != null) {
        _apply(rs, 'POST');
      } else {
        unawaited(refresh());
      }
      return true;
    } catch (e) {
      _selectInFlight--;
      final detail = e is DioException
          ? 'HTTP ${e.response?.statusCode} ${e.message ?? ''}'
          : '$e';
      connTrace('select-dog', 'POST $path dog=$dogId → $detail');
      if (mounted) {
        status.state = DogSelectionStatus(failedAt: DateTime.now());
      }
      return false;
    }
  }

  /// The app's selected dog is the relay's `selected_dog_id` whenever the
  /// record has one. The app never writes it back from here — only the
  /// dog selector does (H2).
  void _reconcileSelectedDog() {
    final rs = state;
    if (rs == null || _selectInFlight > 0) return;
    // Local / AP: the selection is the app's own, never a record's.
    if (isLocalMode) return;
    final remoteId = rs.selectedDogId;
    if (remoteId == null) return;
    if (_ref.read(selectedDogProvider)?.id == remoteId) return;
    for (final p in _ref.read(dogProfilesProvider)) {
      if (p.id == remoteId) {
        connTrace('select-dog', 'selected dog ← robot_state $remoteId');
        unawaited(_ref.read(selectedDogProvider.notifier).adopt(p));
        return;
      }
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsStateSub?.cancel();
    super.dispose();
  }
}
