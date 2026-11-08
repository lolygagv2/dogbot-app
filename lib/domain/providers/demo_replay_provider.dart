import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/replay_admin_api.dart';
import 'auth_provider.dart';
import 'daily_summary_provider.dart';
import 'dog_profiles_provider.dart';
import 'sg_summary_provider.dart';

/// Seed files shipped in the relay's `seeds/` directory.
const kReplaySeedGoodDay = 'demo_good_day.json';
const kReplaySeedBadDay = 'demo_bad_day.json';

/// Relay default demo dog (config `demo_dog_id`); the replayer creates it
/// under the loading admin on first load.
const kReplayDefaultDogId = 'demo_dog';

class DemoReplayState {
  /// null = not probed yet / probing; false hides the panel entirely.
  final bool? isAdmin;
  final ReplayState replay;

  /// `replay_active` from GET /api/dogs/{dog}/status (null = not fetched).
  final bool? replayActive;

  /// Virtual clock from the status endpoint when the relay sends one there;
  /// otherwise null and the panel shows the replayer's own virtual_time.
  final String? statusVirtualTimeRaw;
  final String? statusDogId;
  final bool busy;
  final String? error;

  /// Wall-clock instant the current [replay] snapshot was taken — the panel
  /// advances the displayed clock from here at `speed` while running.
  final DateTime snapshotAt;

  DemoReplayState({
    this.isAdmin,
    this.replay = const ReplayState(),
    this.replayActive,
    this.statusVirtualTimeRaw,
    this.statusDogId,
    this.busy = false,
    this.error,
    DateTime? snapshotAt,
  }) : snapshotAt = snapshotAt ?? DateTime.now();

  DemoReplayState copyWith({
    bool? isAdmin,
    ReplayState? replay,
    bool? replayActive,
    String? statusVirtualTimeRaw,
    bool clearStatusVirtualTime = false,
    String? statusDogId,
    bool? busy,
    String? error,
    bool clearError = false,
    DateTime? snapshotAt,
  }) =>
      DemoReplayState(
        isAdmin: isAdmin ?? this.isAdmin,
        replay: replay ?? this.replay,
        replayActive: replayActive ?? this.replayActive,
        statusVirtualTimeRaw: clearStatusVirtualTime
            ? null
            : (statusVirtualTimeRaw ?? this.statusVirtualTimeRaw),
        statusDogId: statusDogId ?? this.statusDogId,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        snapshotAt: snapshotAt ?? this.snapshotAt,
      );

  /// Best available virtual clock, as the dog's wall time (no tz shift).
  DateTime? get virtualWallTime =>
      ReplayState.parseWallTime(statusVirtualTimeRaw) ?? replay.virtualWallTime;

  /// Dog the replayer is (or will be) driving; used for the status poll.
  String get dogId => replay.dogId ?? kReplayDefaultDogId;
}

final demoReplayProvider =
    StateNotifierProvider<DemoReplayNotifier, DemoReplayState>(
        (ref) => DemoReplayNotifier(ref));

/// Admin demo controls for the relay replayer. Probes `GET /admin/replay`
/// once per attached demo screen: 200 → admin (panel shown), 403/404 → not
/// admin / not deployed (panel hidden). While attached and admin it polls
/// the replayer state and the demo dog's status every [_pollEvery] and
/// refreshes on WS `replay_jump` / `replay_reset` frames.
class DemoReplayNotifier extends StateNotifier<DemoReplayState> {
  static const _pollEvery = Duration(seconds: 4);
  final Ref _ref;
  StreamSubscription? _wsSub;
  Timer? _poll;
  int _attached = 0;

  DemoReplayNotifier(this._ref) : super(DemoReplayState()) {
    _wsSub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'replay_jump' || e.type == 'replay_reset')
        .listen((e) {
      connTrace('replay-ws', '${e.type} ${e.data['virtual_time'] ?? ''}');
      if (_attached > 0 && state.isAdmin == true) refresh();
    });
    // A new login may be a different account: forget the admin verdict.
    _ref.listen<String?>(authTokenProvider, (prev, next) {
      if (prev != next) {
        state = DemoReplayState();
        if (_attached > 0 && next != null) probe();
      }
    });
  }

  String? get _token => _ref.read(authProvider).token;
  ReplayAdminApi get _api => _ref.read(replayAdminApiProvider);

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
      final st = await _api.getState(token);
      if (!mounted) return;
      state = state.copyWith(
          isAdmin: true,
          replay: st,
          snapshotAt: DateTime.now(),
          clearError: true);
      connTrace('replay-probe',
          'admin status=${st.status} seed=${st.seed} vt=${st.virtualTimeRaw}');
      await _pullStatus(token);
      if (_attached > 0) _startPolling();
    } on ReplayNotAdmin {
      if (!mounted) return;
      state = state.copyWith(isAdmin: false);
    } catch (e) {
      // Network blip: leave the verdict open so a later attach re-probes,
      // but don't show controls to an account we can't vouch for.
      if (!mounted) return;
      connTrace('replay-probe-error', '$e');
      state = state.copyWith(isAdmin: false);
    }
  }

  /// Re-read the replayer state + the demo dog's status.
  Future<void> refresh() async {
    final token = _token;
    if (token == null || state.isAdmin != true) return;
    try {
      final st = await _api.getState(token);
      if (!mounted) return;
      state = state.copyWith(replay: st, snapshotAt: DateTime.now());
      await _pullStatus(token);
    } on ReplayNotAdmin {
      if (!mounted) return;
      state = state.copyWith(isAdmin: false);
      _stopPolling();
    } catch (e) {
      if (!mounted) return;
      connTrace('replay-refresh-error', '$e');
    }
  }

  Future<void> _pullStatus(String token) async {
    final dogId = state.dogId;
    try {
      final s = await _api.getDogStatus(token, dogId);
      if (!mounted) return;
      state = state.copyWith(
        replayActive: s.replayActive,
        statusDogId: dogId,
        statusVirtualTimeRaw: s.virtualTimeRaw,
        clearStatusVirtualTime: s.virtualTimeRaw == null,
      );
    } catch (e) {
      // 403/404 before the demo dog exists is expected; shown as "–".
      if (!mounted) return;
      state = state.copyWith(statusDogId: dogId, clearStatusVirtualTime: true);
    }
  }

  Future<bool> _run(String op, Future<ReplayState> Function(String token) call,
      {bool refreshFeeds = false}) async {
    final token = _token;
    if (token == null || state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final st = await call(token);
      if (!mounted) return true;
      state = state.copyWith(
          replay: st,
          busy: false,
          snapshotAt: DateTime.now(),
          clearError: true);
      await _pullStatus(token);
      if (refreshFeeds) _refreshFeeds(st.dogId ?? kReplayDefaultDogId);
      return true;
    } on ReplayNotAdmin {
      if (!mounted) return false;
      state = state.copyWith(isAdmin: false, busy: false);
      _stopPolling();
      return false;
    } catch (e) {
      if (!mounted) return false;
      final msg = e.toString().replaceFirst('Exception: ', '');
      connTrace('replay-$op-error', msg);
      state = state.copyWith(busy: false, error: msg);
      return false;
    }
  }

  /// Load creates/attaches the demo dog to this account and jump/reset
  /// rewrite its day, so the dog list and the Today / Guardian panes need a
  /// fresh pull.
  void _refreshFeeds(String dogId) {
    unawaited(_ref.read(dogProfilesProvider.notifier).hydrateFromRelay());
    final selected = _ref.read(selectedDogProvider);
    if (selected?.id == dogId) {
      unawaited(
          _ref.read(dailySummaryProvider(dogId).notifier).load(refresh: true));
      _ref.read(sgSummaryProvider.notifier).pull();
    }
  }

  Future<bool> loadGoodDay() =>
      _run('load', (t) => _api.load(t, kReplaySeedGoodDay), refreshFeeds: true);

  Future<bool> loadBadDay() =>
      _run('load', (t) => _api.load(t, kReplaySeedBadDay), refreshFeeds: true);

  Future<bool> start({double speed = 120}) =>
      _run('start', (t) => _api.start(t, speed: speed));

  Future<bool> pause() => _run('pause', (t) => _api.pause(t));

  /// [to] = "HH:MM" in the seed timezone.
  Future<bool> jumpTo(String to) =>
      _run('jump', (t) => _api.jumpTo(t, to), refreshFeeds: true);

  Future<bool> reset() =>
      _run('reset', (t) => _api.reset(t), refreshFeeds: true);

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    _wsSub?.cancel();
    _stopPolling();
    super.dispose();
  }
}
