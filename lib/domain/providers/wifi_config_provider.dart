import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/robot_api.dart';

/// WiFi network from scan results
class WifiNetwork {
  final String ssid;
  final int signal;
  final String security;

  const WifiNetwork({
    required this.ssid,
    required this.signal,
    this.security = '',
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String? ?? '',
      signal: json['signal'] as int? ?? 0,
      security: json['security'] as String? ?? '',
    );
  }
}

/// Robot network status
class NetworkStatusData {
  final String mode; // "ap" or "wifi"
  final String networkName;
  final String ipAddress;

  const NetworkStatusData({
    this.mode = '',
    this.networkName = '',
    this.ipAddress = '',
  });

  factory NetworkStatusData.fromJson(Map<String, dynamic> json) {
    return NetworkStatusData(
      mode: json['mode'] as String? ?? '',
      networkName: json['network_name'] as String? ?? json['ssid'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? json['ip'] as String? ?? '',
    );
  }

  bool get isAP => mode.toLowerCase() == 'ap';
  bool get isWifi => mode.toLowerCase() == 'wifi';
}

/// WiFi configuration state
enum WifiConfigStep {
  idle,
  scanning,
  scanComplete,
  scanError,
  connecting,
  connectSent,
  connectionLost,
}

class WifiConfigState {
  final WifiConfigStep step;
  final List<WifiNetwork> networks;
  final String? errorMessage;
  final NetworkStatusData? networkStatus;

  const WifiConfigState({
    this.step = WifiConfigStep.idle,
    this.networks = const [],
    this.errorMessage,
    this.networkStatus,
  });

  WifiConfigState copyWith({
    WifiConfigStep? step,
    List<WifiNetwork>? networks,
    String? errorMessage,
    NetworkStatusData? networkStatus,
    bool clearError = false,
  }) {
    return WifiConfigState(
      step: step ?? this.step,
      networks: networks ?? this.networks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      networkStatus: networkStatus ?? this.networkStatus,
    );
  }
}

/// Provider
final wifiConfigProvider =
    StateNotifierProvider<WifiConfigNotifier, WifiConfigState>((ref) {
  return WifiConfigNotifier(ref);
});

class WifiConfigNotifier extends StateNotifier<WifiConfigState> {
  final Ref _ref;
  Timer? _statusPollTimer;

  WifiConfigNotifier(this._ref) : super(const WifiConfigState());

  RobotApi get _api => _ref.read(robotApiProvider);

  /// Scan for available WiFi networks
  Future<void> scanNetworks() async {
    state = state.copyWith(
      step: WifiConfigStep.scanning,
      networks: [],
      clearError: true,
    );

    try {
      final results = await _api.wifiScan();
      final networks = results
          .map((r) => WifiNetwork.fromJson(r))
          .where((n) => n.ssid.isNotEmpty)
          .toList()
        ..sort((a, b) => b.signal.compareTo(a.signal));

      state = state.copyWith(
        step: WifiConfigStep.scanComplete,
        networks: networks,
      );
    } catch (e) {
      state = state.copyWith(
        step: WifiConfigStep.scanError,
        errorMessage: 'WiFi scan failed: $e',
      );
    }
  }

  /// Connect robot to a WiFi network
  Future<void> connectToNetwork(String ssid, String password) async {
    state = state.copyWith(
      step: WifiConfigStep.connecting,
      clearError: true,
    );

    try {
      await _api.wifiConnect(ssid: ssid, password: password);
      // The robot accepted the command — it will now switch networks.
      // We expect to lose our connection because the AP shuts down.
      state = state.copyWith(step: WifiConfigStep.connectSent);
    } catch (e) {
      // If we got a connection error, the robot may already be switching.
      // Treat timeout/connection errors as "command sent".
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') ||
          msg.contains('connection') ||
          msg.contains('socket')) {
        state = state.copyWith(step: WifiConfigStep.connectSent);
      } else {
        state = state.copyWith(
          step: WifiConfigStep.scanComplete,
          errorMessage: 'Failed to connect: $e',
        );
      }
    }
  }

  /// Mark that the local connection was lost (called from UI)
  void onConnectionLost() {
    if (state.step == WifiConfigStep.connectSent) {
      state = state.copyWith(step: WifiConfigStep.connectionLost);
    }
  }

  /// Start polling network status every 5 seconds
  void startStatusPolling() {
    _statusPollTimer?.cancel();
    _pollNetworkStatus();
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollNetworkStatus(),
    );
  }

  /// Stop polling network status
  void stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  Future<void> _pollNetworkStatus() async {
    try {
      final data = await _api.networkStatus();
      if (data.isNotEmpty) {
        state = state.copyWith(
          networkStatus: NetworkStatusData.fromJson(data),
        );
      }
    } catch (_) {
      // Silently ignore — robot may be unreachable during WiFi switch
    }
  }

  /// Reset back to idle
  void reset() {
    stopStatusPolling();
    state = const WifiConfigState();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }
}
