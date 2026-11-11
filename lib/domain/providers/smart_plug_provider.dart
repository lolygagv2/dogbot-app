import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/smart_plug.dart';

/// State for the "Calming diffuser plug" (Settings → Silent Guardian).
///
/// The robot owns everything: the app only sends `smart_plug` commands and
/// renders the `command_result` / live `smart_plug` events. Nothing is
/// persisted app-side.
class SmartPlugState {
  /// Last known status. Null until the first `status` reply lands.
  final SmartPlugStatus? status;

  /// A `status` request is in flight.
  final bool loading;

  /// The last `status` request got no usable reply (robot offline, old
  /// firmware, timeout). The entry row shows the generic line.
  final bool statusFailed;

  /// A `scan` is in flight.
  final bool scanning;

  /// Plugs from the last scan. Null = never scanned.
  final List<SmartPlugDevice>? plugs;

  /// The last scan itself failed (distinct from an empty list, which is a
  /// normal "none found" result).
  final bool scanFailed;

  /// A mutating command (configure / on / off / remove) is in flight.
  final bool busy;

  const SmartPlugState({
    this.status,
    this.loading = false,
    this.statusFailed = false,
    this.scanning = false,
    this.plugs,
    this.scanFailed = false,
    this.busy = false,
  });

  bool get configured => status?.configured == true;

  SmartPlugState copyWith({
    Object? status = _keep,
    bool? loading,
    bool? statusFailed,
    bool? scanning,
    Object? plugs = _keep,
    bool? scanFailed,
    bool? busy,
  }) {
    return SmartPlugState(
      status: identical(status, _keep) ? this.status : status as SmartPlugStatus?,
      loading: loading ?? this.loading,
      statusFailed: statusFailed ?? this.statusFailed,
      scanning: scanning ?? this.scanning,
      plugs: identical(plugs, _keep)
          ? this.plugs
          : plugs as List<SmartPlugDevice>?,
      scanFailed: scanFailed ?? this.scanFailed,
      busy: busy ?? this.busy,
    );
  }

  static const _keep = Object();
}

/// Outcome of one `smart_plug` command.
class _Reply {
  final bool ok;
  final Map<String, dynamic> result;
  final String? errorCode;
  const _Reply(this.ok, this.result, this.errorCode);
}

final smartPlugProvider =
    StateNotifierProvider<SmartPlugNotifier, SmartPlugState>((ref) {
  return SmartPlugNotifier(ref);
});

class SmartPlugNotifier extends StateNotifier<SmartPlugState> {
  final Ref _ref;
  final _uuid = const Uuid();
  final Map<String, Completer<_Reply>> _pending = {};
  StreamSubscription<WsEvent>? _eventSub;

  static const _replyTimeout = Duration(seconds: 10);
  static const _scanTimeout = Duration(seconds: 15);

  SmartPlugNotifier(this._ref) : super(const SmartPlugState()) {
    _eventSub =
        _ref.read(websocketClientProvider).eventStream.listen(_onEvent);
  }

  // ---------------------------------------------------------------------
  // Wire
  // ---------------------------------------------------------------------

  void _onEvent(WsEvent event) {
    try {
      if (event.type == 'command_result') {
        final id = event.data['command_id']?.toString();
        final completer = id == null ? null : _pending.remove(id);
        if (completer == null) return; // someone else's command
        completer.complete(_parseReply(event.data));
        return;
      }
      // Live state change pushed by the robot: type "smart_plug", or the
      // relay's generic `event` frame carrying it as event_type.
      final isPlugEvent = event.type == 'smart_plug' ||
          (event.type == 'event' &&
              (event.data['event_type'] == 'smart_plug' ||
                  event.data['subtype'] == 'smart_plug'));
      if (!isPlugEvent) return;
      // A replayed backlog frame is history, not the plug's current state.
      if (event.buffered) return;
      final inner = event.data['data'];
      final d = inner is Map
          ? Map<String, dynamic>.from(inner)
          : event.data;
      connTrace('plug-event',
          'on=${d['on']} reason=${d['reason']} owner=${d['owner']}');
      final prev = state.status;
      if (prev == null || !prev.configured) {
        // We have no status yet (or thought nothing was set up) — the event
        // proves a plug exists; fetch the full picture.
        unawaited(refreshStatus());
        return;
      }
      state = state.copyWith(
        status: SmartPlugStatus.fromJson({
          'auto_off_at': null, // absent = no pending auto-off
          ...d,
          'configured': true,
        }, prev: prev),
      );
    } catch (e) {
      connTrace('plug-event-err', '$e');
    }
  }

  _Reply _parseReply(Map<String, dynamic> d) {
    final rawResult = d['result'];
    final result = rawResult is Map
        ? Map<String, dynamic>.from(rawResult)
        : Map<String, dynamic>.from(d);

    String? code;
    for (final err in [d['error'], result['error']]) {
      if (err is Map) {
        code = (err['code'] ?? err['error_code'])?.toString();
      } else if (err is String && err.isNotEmpty) {
        code = err;
      }
      if (code != null) break;
    }
    code ??= (d['error_code'] ?? result['error_code'])?.toString();

    final success = d['success'];
    final ok = success is bool ? success && code == null : code == null;
    if (!ok) code ??= SmartPlugError.noReply;
    return _Reply(ok, result, ok ? null : code);
  }

  Future<_Reply> _request(
    String action, {
    Map<String, dynamic> extra = const {},
    Duration timeout = _replyTimeout,
  }) async {
    final id = _uuid.v4();
    final completer = Completer<_Reply>();
    _pending[id] = completer;
    final sent = _ref.read(websocketClientProvider).sendCommandWithId(
      'smart_plug',
      id,
      {'action': action, ...extra},
    );
    if (!sent) {
      _pending.remove(id);
      return const _Reply(false, {}, SmartPlugError.noReply);
    }
    try {
      final reply = await completer.future.timeout(timeout);
      if (!reply.ok) connTrace('plug-err', '$action code=${reply.errorCode}');
      return reply;
    } on TimeoutException {
      _pending.remove(id);
      connTrace('plug-timeout', '$action after ${timeout.inSeconds}s');
      return const _Reply(false, {}, SmartPlugError.noReply);
    }
  }

  /// Fold a reply's status fields into state. `plug_unreachable` is a normal
  /// state (unplugged / out of range), not an error: mark it and move on.
  /// Returns the error code the UI should surface, or null.
  String? _applyStatusReply(_Reply r) {
    if (!mounted) return null;
    if (r.ok) {
      state = state.copyWith(
        status: SmartPlugStatus.fromJson(r.result, prev: state.status),
        statusFailed: false,
      );
      return null;
    }
    if (r.errorCode == SmartPlugError.plugUnreachable) {
      final prev = state.status;
      state = state.copyWith(
        status: (prev ?? const SmartPlugStatus(configured: true))
            .copyWith(reachable: false),
        statusFailed: false,
      );
      return null;
    }
    return r.errorCode;
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// `status` — called when Silent Guardian settings open and every 60 s
  /// while the Detail screen is up.
  Future<void> refreshStatus() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);
    final r = await _request('status');
    if (!mounted) return;
    final err = _applyStatusReply(r);
    state = state.copyWith(loading: false, statusFailed: err != null);
  }

  /// `scan` — robot looks for Kasa plugs on its WiFi (~3 s, allow 15 s).
  Future<void> scan() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, scanFailed: false);
    final r = await _request('scan', timeout: _scanTimeout);
    if (!mounted) return;
    if (!r.ok) {
      state = state.copyWith(scanning: false, scanFailed: true);
      return;
    }
    final raw = r.result['plugs'];
    final plugs = <SmartPlugDevice>[
      if (raw is List)
        for (final p in raw)
          if (p is Map)
            if (SmartPlugDevice.fromJson(Map<String, dynamic>.from(p))
                case final plug?)
              plug,
    ];
    state = state.copyWith(scanning: false, plugs: plugs, scanFailed: false);
  }

  Future<String?> _mutate(String action, [Map<String, dynamic> extra = const {}]) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    final r = await _request(action, extra: extra);
    if (!mounted) return null;
    final err = _applyStatusReply(r);
    state = state.copyWith(busy: false);
    return err;
  }

  /// Pick a plug. Returns an error code, or null on success.
  Future<String?> selectPlug(String deviceId) async {
    final r = await _requestBusy('configure', {'device_id': deviceId});
    if (r.ok) {
      state = state.copyWith(
        status: SmartPlugStatus.fromJson(
          {...r.result, 'configured': true},
          // A different plug: nothing from the old one carries over.
          prev: state.status?.deviceId == deviceId ? state.status : null,
        ),
        statusFailed: false,
      );
      return null;
    }
    return r.errorCode;
  }

  Future<_Reply> _requestBusy(String action, Map<String, dynamic> extra) async {
    state = state.copyWith(busy: true);
    final r = await _request(action, extra: extra);
    if (mounted) state = state.copyWith(busy: false);
    return r;
  }

  /// Manual switch. Returns an error code, or null (success or unreachable).
  Future<String?> setOn(bool on) => _mutate(on ? 'on' : 'off');

  Future<String?> setTriggerLevel(int level) =>
      _mutate('configure', {'trigger_level': level});

  Future<String?> setAutoOffMinutes(int minutes) =>
      _mutate('configure', {'auto_off_minutes': minutes});

  /// Forget the plug. Returns an error code, or null on success.
  Future<String?> remove() async {
    final r = await _requestBusy('remove', const {});
    if (!mounted) return null;
    if (r.ok) {
      state = state.copyWith(
        status: const SmartPlugStatus(configured: false),
        plugs: null,
        statusFailed: false,
      );
      return null;
    }
    return r.errorCode;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(const _Reply(false, {}, SmartPlugError.noReply));
      }
    }
    _pending.clear();
    super.dispose();
  }
}
