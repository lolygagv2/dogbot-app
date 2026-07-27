import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'connection_provider.dart';

/// The robot's own hotspot credentials, carried inside `network_state` /
/// `local_mode_starting` events (robot contract 2026-07-26). Single-SSID
/// scheme: `WIMZ-<serial>` / `wimzsetup` at 192.168.4.1 for every scenario
/// (setup portal, WiFi-loss fallback, app-commanded local mode).
class RobotLocalAp {
  final String ssid;
  final String password;
  final String ip;
  final String api;
  final String ws;

  const RobotLocalAp({
    required this.ssid,
    required this.password,
    required this.ip,
    required this.api,
    required this.ws,
  });

  static RobotLocalAp? fromJson(dynamic json) {
    if (json is! Map) return null;
    final ssid = json['ssid']?.toString();
    if (ssid == null || ssid.isEmpty) return null;
    final ip = json['ip']?.toString() ?? '192.168.4.1';
    return RobotLocalAp(
      ssid: ssid,
      password: json['password']?.toString() ?? 'wimzsetup',
      ip: ip,
      api: json['api']?.toString() ?? 'http://$ip:8000',
      ws: json['ws']?.toString() ?? 'ws://$ip:8000/ws/local',
    );
  }

  Map<String, dynamic> toJson() =>
      {'ssid': ssid, 'password': password, 'ip': ip, 'api': api, 'ws': ws};
}

/// Latest network breadcrumb for one robot — sent on every relay connect and
/// after every successful WiFi rejoin. The cached `localAp` is what makes the
/// offline "join the robot's hotspot" prompt possible: by the time the robot
/// is on its AP, it can't tell us the credentials anymore.
class RobotNetworkState {
  final String deviceId;
  final String mode; // 'wifi' | 'ap'
  final String? ssid; // current WiFi SSID (null in AP mode)
  final String? ip;
  final int? signal; // dBm, may be null
  final RobotLocalAp? localAp;
  final DateTime updatedAt;

  const RobotNetworkState({
    required this.deviceId,
    required this.mode,
    this.ssid,
    this.ip,
    this.signal,
    this.localAp,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'mode': mode,
        'ssid': ssid,
        'ip': ip,
        'signal': signal,
        'local_ap': localAp?.toJson(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static RobotNetworkState? fromJson(dynamic json) {
    if (json is! Map) return null;
    final deviceId = json['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty) return null;
    return RobotNetworkState(
      deviceId: deviceId,
      mode: json['mode']?.toString() ?? 'wifi',
      ssid: json['ssid']?.toString(),
      ip: json['ip']?.toString(),
      signal: (json['signal'] is num) ? (json['signal'] as num).toInt() : null,
      localAp: RobotLocalAp.fromJson(json['local_ap']),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

/// Caches the latest `network_state` per robot and persists the whole map so
/// the hotspot credentials survive app restarts — the prompt is needed
/// precisely when the robot can no longer be asked.
class NetworkStateNotifier
    extends StateNotifier<Map<String, RobotNetworkState>> {
  static const String _prefsKey = 'robot_network_state_v1';

  StreamSubscription? _wsSubscription;

  NetworkStateNotifier(Ref ref) : super(const {}) {
    _load();
    _wsSubscription = ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'network_state' || e.type == 'local_mode_starting')
        .listen(_onNetworkState);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final loaded = <String, RobotNetworkState>{};
      for (final entry in decoded.entries) {
        final ns = RobotNetworkState.fromJson(entry.value);
        if (ns != null) loaded[entry.key.toString()] = ns;
      }
      if (!mounted) return;
      // Events that raced the async load win: they're fresher than disk.
      state = {...loaded, ...state};
    } catch (e) {
      connTrace('network-state-load-err', '$e');
    }
  }

  void _onNetworkState(WsEvent event) {
    // Relay frames put the payload at the top level (WsEvent.fromJson folds it
    // into data). device_id may sit in data for either envelope shape.
    final ns = RobotNetworkState.fromJson({
      ...event.data,
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (ns == null) {
      connTrace('network-state-skip', 'no device_id in ${event.type}');
      return;
    }
    connTrace('network-state',
        '${event.type} ${ns.deviceId} mode=${ns.mode} ap=${ns.localAp?.ssid}');
    state = {...state, ns.deviceId: ns};
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (e) {
      connTrace('network-state-save-err', '$e');
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Latest network breadcrumb per robot device_id.
final networkStateProvider = StateNotifierProvider<NetworkStateNotifier,
    Map<String, RobotNetworkState>>((ref) {
  return NetworkStateNotifier(ref);
});

/// Breadcrumb for the currently targeted robot (null if none cached yet).
final targetRobotNetworkStateProvider = Provider<RobotNetworkState?>((ref) {
  final deviceId = ref.watch(connectionProvider).deviceId;
  if (deviceId == null) return null;
  return ref.watch(networkStateProvider)[deviceId];
});
