import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';

final replayAdminApiProvider = Provider<ReplayAdminApi>((ref) {
  return ReplayAdminApi(ref.watch(dioClientProvider));
});

/// Thrown by the state probe (`GET /admin/replay`) only, when the relay
/// answers 403 `admin_only` (or 404: replay router not deployed) — the caller
/// hides the demo controls. Button calls never throw this: their failures
/// are [ReplayCallError]s shown on the panel.
class ReplayNotAdmin implements Exception {
  final int? status;
  const ReplayNotAdmin(this.status);
  @override
  String toString() => 'ReplayNotAdmin($status)';
}

/// Snapshot of the relay replayer (`GET /admin/replay`, replayer.state()).
/// A failed replay/status call, with what the panel shows: the call, the
/// HTTP status (null = no response) and the relay's error text.
class ReplayCallError implements Exception {
  final String call; // "POST /admin/replay/load"
  final int? status;
  final String text;

  /// 409 `replay_other_dog`: the dog whose replay is loaded instead.
  final String? loadedDogId;
  const ReplayCallError(this.call, this.status, this.text, {this.loadedDogId});

  ReplayCallError withText(String t) =>
      ReplayCallError(call, status, t, loadedDogId: loadedDogId);

  /// "POST /admin/replay/load → HTTP 404 · seed_not_found"
  String get display =>
      '$call → ${status != null ? 'HTTP $status' : 'no response'}'
      '${text.isEmpty ? '' : ' · $text'}';
  @override
  String toString() => display;
}

/// Who a replay call is aimed at: the dog selected in the app and the robot
/// that is online (null = none online; the field is then omitted).
class ReplayTarget {
  final String dogId;
  final String? deviceId;
  const ReplayTarget({required this.dogId, this.deviceId});

  Map<String, dynamic> get fields => {
        'dog_id': dogId,
        if (deviceId != null) 'device_id': deviceId,
      };
}

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

  /// Events THIS call wrote (`landed`; relay reply 2026-11-18): load good
  /// day = the recap written onto [landedDate] (yesterday), bad day = 0,
  /// jump = what the jump wrote. Null on responses that don't carry it.
  /// [emitted] is the running total, never a per-call count.
  final int? landed;
  final String? landedDate;

  /// Events taken back (backward jump) or deleted (reset).
  final int? removed;

  /// `GET /admin/replay?dog_id=` while ANOTHER dog's replay is loaded:
  /// status is idle for our dog and this names the dog that has it.
  final String? busyWithDogId;

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
    this.landed,
    this.landedDate,
    this.removed,
    this.busyWithDogId,
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
      landed: j['landed'] is num ? (j['landed'] as num).toInt() : null,
      landedDate: str(j['landed_date']),
      removed: j['removed'] is num ? (j['removed'] as num).toInt() : null,
      busyWithDogId:
          j['busy_with'] is Map ? str((j['busy_with'] as Map)['dog_id']) : null,
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
  final String? deviceId;

  /// Status `virtual_time` (relay 2026-11-18): null unless THIS dog's replay
  /// is loaded.
  final String? virtualTimeRaw;
  const DogReplayStatus({
    required this.replayActive,
    this.robotOnline = false,
    this.mode,
    this.deviceId,
    this.virtualTimeRaw,
  });
}

/// Admin-only demo replayer controls (relay brief 2026-11-06 "Demo tooling",
/// router `replay.py`). Every call carries the user JWT; the relay treats the
/// token as admin only when the account email is in its admin list.
///
/// Every call also carries the [ReplayTarget] (selected dog + online robot)
/// and is traced as `replay-http` with its full URL, body and HTTP status
/// (Settings → Connection Diagnostics).
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

  /// Status + relay error text for a failed call; traces it too.
  ReplayCallError _error(DioException e, String method, String path,
      Object? body) {
    final code = e.response?.statusCode;
    var text = relayErrorMessage(e);
    if (code != null && text == 'HTTP $code') {
      // No relay error envelope: show the raw body (proxy / HTML error).
      final raw = e.response?.data?.toString().trim() ?? '';
      text = raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
    } else if (code == null) {
      text = '${e.type.name}${e.message != null ? ' ${e.message}' : ''}';
    }
    connTrace('replay-http',
        '$method ${e.requestOptions.uri} body=${body ?? '-'} -> ${code ?? 'no response'} $text');
    final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
    return ReplayCallError('$method $path', code, text,
        loadedDogId:
            detail is Map ? detail['loaded_dog_id']?.toString() : null);
  }

  Future<ReplayState> getState(String token, {ReplayTarget? target}) async {
    try {
      final r = await _dio.get(ApiEndpoints.adminReplay,
          queryParameters: target?.fields, options: _auth(token));
      return _parse(r.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final err = _error(e, 'GET', ApiEndpoints.adminReplay, null);
      if (code == 403 || code == 404) throw ReplayNotAdmin(code);
      throw err;
    }
  }

  Future<ReplayState> _post(String token, String path, ReplayTarget target,
      [Map<String, dynamic> extra = const {}]) async {
    final body = {...extra, ...target.fields};
    try {
      final r = await _dio.post(path, data: body, options: _auth(token));
      final st = _parse(r.data);
      connTrace('replay-http',
          'POST ${r.requestOptions.uri} body=$body -> ${r.statusCode} '
              'status=${st.status} seed=${st.seed} dog=${st.dogId} device=${st.deviceId} '
              'date=${st.date} cursor=${st.cursor}/${st.total} emitted=${st.emitted} '
              'landed=${st.landed} landed_date=${st.landedDate} removed=${st.removed} vt=${st.virtualTimeRaw}');
      return st;
    } on DioException catch (e) {
      throw _error(e, 'POST', path, body);
    }
  }

  /// Loads a seed for [target]. No `date` is sent: the relay places the seed
  /// (good day = recap written onto yesterday + replay as today; bad day =
  /// replay as today) and reports `date` / `landed` / `landed_date`.
  Future<ReplayState> load(String token, String seed, ReplayTarget target) =>
      _post(token, ApiEndpoints.adminReplayLoad, target, {'seed': seed});

  Future<ReplayState> start(String token, ReplayTarget target,
          {double? speed}) =>
      _post(token, ApiEndpoints.adminReplayStart, target,
          {if (speed != null) 'speed': speed});

  Future<ReplayState> pause(String token, ReplayTarget target) =>
      _post(token, ApiEndpoints.adminReplayPause, target);

  /// [to] is "HH:MM" in the seed's timezone.
  Future<ReplayState> jumpTo(String token, String to, ReplayTarget target) =>
      _post(token, ApiEndpoints.adminReplayJump, target, {'to': to});

  /// Stops the replayer and deletes the target dog's replayed data.
  Future<ReplayState> reset(String token, ReplayTarget target) =>
      _post(token, ApiEndpoints.adminReplayReset, target);

  /// Replay flag (and any virtual clock) from the dog status endpoint.
  Future<DogReplayStatus> getDogStatus(String token, String dogId) async {
    final path = ApiEndpoints.dogStatus(dogId);
    try {
      final r = await _dio.get(path, options: _auth(token));
      final d = r.data;
      if (d is Map) {
        final vt = d['virtual_time'] ??
            d['replay_virtual_time'] ??
            (d['replay'] is Map ? (d['replay'] as Map)['virtual_time'] : null);
        return DogReplayStatus(
          replayActive: d['replay_active'] == true,
          robotOnline: d['robot_online'] == true,
          mode: d['mode']?.toString(),
          deviceId: d['device_id']?.toString(),
          virtualTimeRaw: vt?.toString(),
        );
      }
      return const DogReplayStatus(replayActive: false);
    } on DioException catch (e) {
      throw _error(e, 'GET', path, null);
    }
  }
}
