import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';

final replayAdminApiProvider = Provider<ReplayAdminApi>((ref) {
  return ReplayAdminApi(ref.watch(dioClientProvider));
});

/// Thrown when the relay answers 403 `admin_only` (or 404: replay router not
/// deployed) — the caller hides the demo controls.
class ReplayNotAdmin implements Exception {
  final int? status;
  const ReplayNotAdmin(this.status);
  @override
  String toString() => 'ReplayNotAdmin($status)';
}

/// Snapshot of the relay replayer (`GET /admin/replay`, replayer.state()).
class ReplayState {
  final String status; // idle | loaded | running | paused | done
  final String? seed; // file name, e.g. demo_good_day.json
  final String? name; // seed display name
  final String? dogId;
  final String? deviceId;
  final String? date; // YYYY-MM-DD in the seed timezone
  final String? timezone;
  final double speed;
  final int cursor;
  final int total;
  final int emitted;

  /// Virtual clock as the relay sent it (ISO 8601 with the dog-tz offset).
  final String? virtualTimeRaw;
  final String? nextEvent;

  const ReplayState({
    this.status = 'idle',
    this.seed,
    this.name,
    this.dogId,
    this.deviceId,
    this.date,
    this.timezone,
    this.speed = 60,
    this.cursor = 0,
    this.total = 0,
    this.emitted = 0,
    this.virtualTimeRaw,
    this.nextEvent,
  });

  bool get isIdle => status == 'idle';
  bool get isRunning => status == 'running';
  bool get isLoaded => !isIdle;

  /// Wall-clock time in the dog's timezone, with the offset stripped so the
  /// result formats as the dog's local time (DateTime.parse would otherwise
  /// shift it to UTC). Null when nothing is loaded.
  DateTime? get virtualWallTime => parseWallTime(virtualTimeRaw);

  static DateTime? parseWallTime(String? raw) {
    if (raw == null || raw.length < 16) return null;
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(?::\d{2})?)')
        .firstMatch(raw);
    if (m == null) return null;
    return DateTime.tryParse('${m.group(1)}T${m.group(2)}');
  }

  static ReplayState fromJson(Map<String, dynamic> j) {
    String? str(dynamic v) {
      final s = v?.toString();
      return (s == null || s.isEmpty || s == 'null') ? null : s;
    }

    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return ReplayState(
      status: str(j['status']) ?? 'idle',
      seed: str(j['seed']),
      name: str(j['name']),
      dogId: str(j['dog_id']),
      deviceId: str(j['device_id']),
      date: str(j['date']),
      timezone: str(j['timezone']),
      speed: (j['speed'] is num)
          ? (j['speed'] as num).toDouble()
          : double.tryParse('${j['speed']}') ?? 60,
      cursor: i(j['cursor']),
      total: i(j['total']),
      emitted: i(j['emitted']),
      virtualTimeRaw: str(j['virtual_time']),
      nextEvent: str(j['next_event']),
    );
  }
}

/// `GET /api/dogs/{dog}/status` — only the replay-related fields.
class DogReplayStatus {
  final bool replayActive;
  final bool robotOnline;
  final String? mode;

  /// Present only if the live relay adds a virtual clock to the status body
  /// (not in the 2026-11-06 brief); the panel falls back to the replayer's
  /// own `virtual_time` when null.
  final String? virtualTimeRaw;
  const DogReplayStatus({
    required this.replayActive,
    this.robotOnline = false,
    this.mode,
    this.virtualTimeRaw,
  });
}

/// Admin-only demo replayer controls (relay brief 2026-11-06 "Demo tooling",
/// router `replay.py`). Every call carries the user JWT; the relay treats the
/// token as admin only when the account email is in its admin list.
class ReplayAdminApi {
  final Dio _dio;
  ReplayAdminApi(this._dio);

  Options _auth(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 15),
      );

  ReplayState _parse(dynamic data) {
    if (data is Map) return ReplayState.fromJson(data.cast<String, dynamic>());
    return const ReplayState();
  }

  Never _throw(DioException e, String op) {
    final code = e.response?.statusCode;
    if (code == 403 || code == 404) {
      connTrace('replay-$op', 'not admin / not deployed ($code)');
      throw ReplayNotAdmin(code);
    }
    final msg = relayErrorMessage(e);
    connTrace('replay-$op-error', 'status=$code $msg');
    throw Exception(msg);
  }

  Future<ReplayState> getState(String token) async {
    try {
      final r = await _dio.get(ApiEndpoints.adminReplay, options: _auth(token));
      return _parse(r.data);
    } on DioException catch (e) {
      _throw(e, 'state');
    }
  }

  Future<ReplayState> _post(String token, String path, String op,
      [Map<String, dynamic>? body]) async {
    try {
      final r = await _dio.post(path, data: body, options: _auth(token));
      final st = _parse(r.data);
      connTrace('replay-$op',
          'status=${st.status} seed=${st.seed} cursor=${st.cursor}/${st.total} vt=${st.virtualTimeRaw}');
      return st;
    } on DioException catch (e) {
      _throw(e, op);
    }
  }

  /// Loads a seed file for the demo dog (relay default `demo_dog` /
  /// `demo_robot`, today in the seed's timezone).
  Future<ReplayState> load(String token, String seed,
          {String? dogId, String? date}) =>
      _post(token, ApiEndpoints.adminReplayLoad, 'load', {
        'seed': seed,
        if (dogId != null) 'dog_id': dogId,
        if (date != null) 'date': date,
      });

  Future<ReplayState> start(String token, {double? speed}) => _post(
      token,
      ApiEndpoints.adminReplayStart,
      'start',
      speed != null ? {'speed': speed} : null);

  Future<ReplayState> pause(String token) =>
      _post(token, ApiEndpoints.adminReplayPause, 'pause');

  Future<ReplayState> setSpeed(String token, double speed) =>
      _post(token, ApiEndpoints.adminReplaySpeed, 'speed', {'speed': speed});

  /// [to] is "HH:MM" in the seed's timezone.
  Future<ReplayState> jumpTo(String token, String to) =>
      _post(token, ApiEndpoints.adminReplayJump, 'jump', {'to': to});

  /// Stops the replayer and deletes the demo dog's replayed data.
  Future<ReplayState> reset(String token) =>
      _post(token, ApiEndpoints.adminReplayReset, 'reset');

  /// Replay flag (and any virtual clock) from the dog status endpoint.
  Future<DogReplayStatus> getDogStatus(String token, String dogId) async {
    try {
      final r =
          await _dio.get(ApiEndpoints.dogStatus(dogId), options: _auth(token));
      final d = r.data;
      if (d is Map) {
        final vt = d['virtual_time'] ??
            d['replay_virtual_time'] ??
            (d['replay'] is Map ? (d['replay'] as Map)['virtual_time'] : null);
        return DogReplayStatus(
          replayActive: d['replay_active'] == true,
          robotOnline: d['robot_online'] == true,
          mode: d['mode']?.toString(),
          virtualTimeRaw: vt?.toString(),
        );
      }
      return const DogReplayStatus(replayActive: false);
    } on DioException catch (e) {
      final msg = relayErrorMessage(e);
      connTrace('replay-status-error',
          'dog=$dogId status=${e.response?.statusCode} $msg');
      throw Exception(msg);
    }
  }
}
