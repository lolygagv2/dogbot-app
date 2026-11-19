import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/replay_admin_api.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';
import 'daily_summary_provider.dart';
import 'device_provider.dart';
import 'dog_profiles_provider.dart';
import 'l10n_provider.dart';
import 'paired_devices_provider.dart';
import 'notifications_provider.dart';
import 'sg_summary_provider.dart';

/// Seed files shipped in the relay's `seeds/` directory.
const kReplaySeedGoodDay = 'demo_good_day.json';
const kReplaySeedBadDay = 'demo_bad_day.json';

/// device_id of the robot that is online right now, or null. The robot this
/// session is bound to wins when the relay reports it online; otherwise the
/// first paired robot the relay has marked online.
final onlineRobotDeviceIdProvider = Provider<String?>((ref) {
  final conn = ref.watch(connectionProvider);
  if (conn.status == ConnectionStatus.robotOnline &&
      !conn.isDemoMode &&
      ref.watch(hasSelectedDeviceProvider)) {
    return ref.watch(deviceIdProvider);
  }
  final paired = ref.watch(pairedDevicesProvider);
  for (final d in paired.devices) {
    if (paired.deviceOnlineStatus[d.deviceId] ?? d.isOnline) return d.deviceId;
  }
  return null;
});

/// What the last successful load / jump / reset did, as the relay reported
/// it. [seed] is null for a reset (only [removed] applies).
class ReplayResult {
  final String? seed;
  final String dogId;
  final String? date;

  /// Events this call wrote; null when the relay didn't say.
  final int? landed;

  /// Set for the good-day recap (written onto yesterday).
  final String? landedDate;
  final int? removed;
  const ReplayResult({
    this.seed,
    required this.dogId,
    this.date,
    this.landed,
    this.landedDate,
    this.removed,
  });
}

/// Everything shown on the demo controls panel is relay state: [replay] is
/// the last `/admin/replay` response, [replayActive] the selected dog's
/// `GET /api/dogs/{dog}/status`. Nothing is predicted or advanced locally.
class DemoReplayState {
  /// null = not probed yet / probing; false hides the panel entirely.
  final bool? isAdmin;
  final ReplayState replay;

  /// `replay_active` from the status endpoint for [statusDogId]
  /// (null = not fetched, or the fetch failed).
  final bool? replayActive;

  /// Virtual clock from the status endpoint when the relay sends one there.
  final String? statusVirtualTimeRaw;
  final String? statusDogId;
  final bool busy;

  /// Failed button call ("POST … → HTTP 409 · replay_not_loaded"); stays
  /// until the next button or dismissal.
  final String? error;

  /// Failed background read (state / status poll); replaced by each poll.
  final String? pollError;
  final ReplayResult? result;

  const DemoReplayState({
    this.isAdmin,
    this.replay = const ReplayState(),
    this.replayActive,
    this.statusVirtualTimeRaw,
    this.statusDogId,
    this.busy = false,
    this.error,
    this.pollError,
    this.result,
  });

  static const _keep = Object();

  DemoReplayState copyWith({
    bool? isAdmin,
    ReplayState? replay,
    Object? replayActive = _keep,
    Object? statusVirtualTimeRaw = _keep,
    Object? statusDogId = _keep,
    bool? busy,
    Object? error = _keep,
    Object? pollError = _keep,
    Object? result = _keep,
  }) =>
      DemoReplayState(
        isAdmin: isAdmin ?? this.isAdmin,
        replay: replay ?? this.replay,
        replayActive: identical(replayActive, _keep)
            ? this.replayActive
            : replayActive as bool?,
        statusVirtualTimeRaw: identical(statusVirtualTimeRaw, _keep)
            ? this.statusVirtualTimeRaw
            : statusVirtualTimeRaw as String?,
        statusDogId: identical(statusDogId, _keep)
            ? this.statusDogId
            : statusDogId as String?,
        busy: busy ?? this.busy,
        error: identical(error, _keep) ? this.error : error as String?,
        pollError:
            identical(pollError, _keep) ? this.pollError : pollError as String?,
        result: identical(result, _keep) ? this.result : result as ReplayResult?,
      );

  /// Dog whose replay is loaded when it isn't the selected one
  /// (`busy_with`, or an older relay answering with its own dog_id).
  String? otherReplayDog(String? dogId) =>
      replay.busyWithDogId ??
      (replay.isLoaded && replay.dogId != dogId ? replay.dogId : null);

  /// True when the relay's replayer is on [dogId] (the selected dog).
  bool replayIsFor(String? dogId) =>
      dogId != null && replay.isLoaded && replay.dogId == dogId;

  /// Relay virtual clock for [dogId] as the dog's wall time, or null when
  /// the replayer is idle or driving a different dog.
  DateTime? virtualWallTimeFor(String? dogId) {
    if (dogId == null) return null;
    if (statusDogId == dogId) {
      final t = ReplayState.parseWallTime(statusVirtualTimeRaw);
      if (t != null) return t;
    }
    return replayIsFor(dogId) ? replay.virtualWallTime : null;
  }
}

final demoReplayProvider =
    StateNotifierProvider<DemoReplayNotifier, DemoReplayState>(
        (ref) => DemoReplayNotifier(ref));

/// Admin demo controls for the relay replayer. Probes `GET /admin/replay`
/// once per attached demo screen: 200 → admin (panel shown), 403/404 → not
/// admin / not deployed (panel hidden). While attached and admin it polls
/// the replayer state and the SELECTED dog's status every [_pollEvery] and
/// refreshes on WS `replay_jump` / `replay_reset` frames and when the
/// selected dog changes.
class DemoReplayNotifier extends StateNotifier<DemoReplayState> {
  static const _pollEvery = Duration(seconds: 2);
  final Ref _ref;
  StreamSubscription? _wsSub;
  Timer? _poll;
  int _attached = 0;

  DemoReplayNotifier(this._ref) : super(const DemoReplayState()) {
    _wsSub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) =>
            e.type == 'replay_jump' ||
            e.type == 'replay_reset' ||
            e.type == 'replay_landed')
        .listen((e) {
      connTrace('replay-ws',
          '${e.type} dog=${e.data['dog_id'] ?? ''} ${e.data['virtual_time'] ?? ''} landed=${e.data['landed'] ?? ''}');
      if (_attached == 0 || state.isAdmin != true) return;
      refresh();
      // The good-day recap has been written: the Today card can pull it.
      final dogId = e.data['dog_id']?.toString();
      if (e.type == 'replay_landed' && dogId != null) _refreshFeeds(dogId);
    });
    // A new login may be a different account: forget the admin verdict.
    _ref.listen<String?>(authTokenProvider, (prev, next) {
      if (prev != next) {
        state = const DemoReplayState();
        if (_attached > 0 && next != null) probe();
      }
    });
    // A different dog is a different target: drop what was read for the old
    // one and re-read the relay for the new one.
    _ref.listen<String?>(selectedDogProvider.select((d) => d?.id),
        (prev, next) {
      if (prev == next) return;
      state = state.copyWith(
          replayActive: null,
          statusVirtualTimeRaw: null,
          statusDogId: null,
          error: null,
          pollError: null,
          result: null);
      if (_attached > 0 && state.isAdmin == true) refresh();
    });
  }

  String? get _token => _ref.read(authProvider).token;
  ReplayAdminApi get _api => _ref.read(replayAdminApiProvider);

  /// Selected dog + online robot, read at call time. Null = no dog selected.
  ReplayTarget? get target {
    final dog = _ref.read(selectedDogProvider);
    if (dog == null) return null;
    return ReplayTarget(
        dogId: dog.id, deviceId: _ref.read(onlineRobotDeviceIdProvider));
  }

  /// Called by the demo screen on show / hide.
  void attach() {
    _attached++;
    if (state.isAdmin == null) {
      probe();
    } else if (state.isAdmin == true) {
      refresh();
      _startPolling();
    }
  }

  void detach() {
    _attached = (_attached - 1).clamp(0, 1 << 20);
    if (_attached == 0) _stopPolling();
  }

  void _startPolling() {
    _poll ??= Timer.periodic(_pollEvery, (_) {
      if (state.busy) return;
      refresh();
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// One GET /admin/replay decides whether this account is an admin.
  Future<void> probe() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(isAdmin: false);
      return;
    }
    try {
      final st = await _api.getState(token, target: target);
      if (!mounted) return;
      state = state.copyWith(isAdmin: true, replay: st, pollError: null);
      connTrace('replay-probe',
          'admin status=${st.status} seed=${st.seed} dog=${st.dogId} vt=${st.virtualTimeRaw}');
      await _pullStatus(token);
      if (_attached > 0) _startPolling();
    } on ReplayNotAdmin {
      if (!mounted) return;
      state = state.copyWith(isAdmin: false);
    } on ReplayCallError catch (e) {
      if (!mounted) return;
      if (e.status != null && e.status != 401) {
        // The relay answered past its admin check (e.g. 422: no dog selected
        // yet, dog_id is required): this IS an admin — show the panel with
        // the error instead of hiding the controls.
        state = state.copyWith(isAdmin: true, pollError: e.display);
        if (_attached > 0) _startPolling();
      }
      // No response (network blip) / 401: verdict stays open, so the next
      // attach re-probes; controls stay hidden meanwhile.
    } catch (e) {
      if (!mounted) return;
      connTrace('replay-probe-error', '$e');
    }
  }

  /// Re-read the replayer state + the selected dog's status from the relay.
  Future<void> refresh() async {
    final token = _token;
    if (token == null || state.isAdmin != true) return;
    try {
      final st = await _api.getState(token, target: target);
      if (!mounted) return;
      state = state.copyWith(replay: st, pollError: null);
      await _pullStatus(token);
    } on ReplayNotAdmin {
      if (!mounted) return;
      state = state.copyWith(isAdmin: false);
      _stopPolling();
    } on ReplayCallError catch (e) {
      if (!mounted) return;
      state = state.copyWith(pollError: e.display);
    } catch (e) {
      if (!mounted) return;
      connTrace('replay-refresh-error', '$e');
      state = state.copyWith(pollError: '$e');
    }
  }

  /// `replay_active` for the selected dog, straight from its status endpoint.
  Future<void> _pullStatus(String token) async {
    final dogId = _ref.read(selectedDogProvider)?.id;
    if (dogId == null) {
      state = state.copyWith(
          replayActive: null, statusDogId: null, statusVirtualTimeRaw: null);
      return;
    }
    try {
      final s = await _api.getDogStatus(token, dogId);
      if (!mounted) return;
      state = state.copyWith(
        replayActive: s.replayActive,
        statusDogId: dogId,
        statusVirtualTimeRaw: s.virtualTimeRaw,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        replayActive: null,
        statusDogId: dogId,
        statusVirtualTimeRaw: null,
        pollError: e is ReplayCallError ? e.display : '$e',
      );
    }
  }

  /// One button call. On success the panel takes the relay's response and
  /// re-reads the dog status; on failure it shows the status code and text.
  /// [landing] = a load / jump that should refresh the Today card and
  /// report what landed.
  Future<bool> _run(
      String op,
      Future<ReplayState> Function(String token, ReplayTarget target) call,
      {bool landing = false, bool refreshFeeds = false}) async {
    final token = _token;
    if (token == null || state.busy) return false;
    final t = target;
    if (t == null) {
      state = state.copyWith(error: _ref.read(l10nProvider).demoNoDog);
      return false;
    }
    state = state.copyWith(busy: true, error: null, result: null);
    try {
      final st = await call(token, t);
      if (!mounted) return true;
      // The relay must answer for the dog we asked for; say so if it didn't
      // (e.g. an older relay ignoring dog_id) instead of showing a success.
      final answeredFor = st.dogId;
      final wrongDog = st.isLoaded && answeredFor != t.dogId;
      state = state.copyWith(
        replay: st,
        busy: false,
        error: wrongDog
            ? _ref
                .read(l10nProvider)
                .demoWrongTarget(answeredFor ?? '–', _dogLabel(t.dogId))
            : null,
        result: wrongDog
            ? null
            : landing
                ? ReplayResult(
                    seed: st.name ?? st.seed ?? '–',
                    dogId: answeredFor ?? t.dogId,
                    date: st.date,
                    landed: st.landed,
                    landedDate: st.landedDate,
                    removed: st.removed,
                  )
                : (op == 'reset'
                    ? ReplayResult(dogId: t.dogId, removed: st.removed)
                    : null),
      );
      await _pullStatus(token);
      if (landing || refreshFeeds) _refreshFeeds(t.dogId);
      return !wrongDog;
    } on ReplayCallError catch (e) {
      if (!mounted) return false;
      // 409 replay_other_dog: name the dog that holds the replay.
      final other = e.loadedDogId;
      final shown = other == null
          ? e
          : e.withText(
              _ref.read(l10nProvider).demoReplayOtherDog(_dogLabel(other)));
      state = state.copyWith(busy: false, error: shown.display);
      return false;
    } catch (e) {
      if (!mounted) return false;
      connTrace('replay-$op-error', '$e');
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  String _dogLabel(String dogId) =>
      _ref.read(dogProfileProvider(dogId))?.name ?? dogId;

  /// Load / jump / reset rewrite the dog's day: recompute the Today card
  /// roll-up and re-pull the Guardian pane for the targeted dog.
  void _refreshFeeds(String dogId) {
    unawaited(
        _ref.read(dailySummaryProvider(dogId).notifier).load(refresh: true));
    _ref.read(sgSummaryProvider.notifier).pull();
    // Events tab: pull the rows the replay just wrote, with their media.
    unawaited(_ref.read(notificationsProvider.notifier).hydrateFromRelay());
  }

  Future<bool> loadGoodDay() => _run(
      'load', (t, tg) => _api.load(t, kReplaySeedGoodDay, tg),
      landing: true);

  Future<bool> loadBadDay() => _run(
      'load', (t, tg) => _api.load(t, kReplaySeedBadDay, tg),
      landing: true);

  Future<bool> start({double speed = 120}) =>
      _run('start', (t, tg) => _api.start(t, tg, speed: speed));

  Future<bool> pause() => _run('pause', (t, tg) => _api.pause(t, tg));

  /// [to] = "HH:MM" in the seed timezone.
  Future<bool> jumpTo(String to) =>
      _run('jump', (t, tg) => _api.jumpTo(t, to, tg), landing: true);

  Future<bool> reset() =>
      _run('reset', (t, tg) => _api.reset(t, tg), refreshFeeds: true);

  void clearError() => state = state.copyWith(error: null);

  @override
  void dispose() {
    _wsSub?.cancel();
    _stopPolling();
    super.dispose();
  }
}
