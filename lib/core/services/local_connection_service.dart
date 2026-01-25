import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../network/websocket_client.dart';
import '../utils/remote_logger.dart';

/// Local connection state
enum LocalConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Local connection state data
class LocalConnectionData {
  final LocalConnectionState state;
  final String? robotIp;
  final int port;
  final String? errorMessage;
  final List<String> discoveredDevices;

  const LocalConnectionData({
    this.state = LocalConnectionState.disconnected,
    this.robotIp,
    this.port = 8000,
    this.errorMessage,
    this.discoveredDevices = const [],
  });

  LocalConnectionData copyWith({
    LocalConnectionState? state,
    String? robotIp,
    int? port,
    String? errorMessage,
    List<String>? discoveredDevices,
    bool clearError = false,
  }) {
    return LocalConnectionData(
      state: state ?? this.state,
      robotIp: robotIp ?? this.robotIp,
      port: port ?? this.port,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }

  bool get isConnected => state == LocalConnectionState.connected;
  bool get isScanning => state == LocalConnectionState.scanning;
  bool get isConnecting => state == LocalConnectionState.connecting;
}

/// Provider for local connection service
final localConnectionProvider =
    StateNotifierProvider<LocalConnectionNotifier, LocalConnectionData>((ref) {
  return LocalConnectionNotifier();
});

/// Local connection service for direct robot connection
class LocalConnectionNotifier extends StateNotifier<LocalConnectionData> {
  Timer? _scanTimer;

  LocalConnectionNotifier() : super(const LocalConnectionData());

  /// Default robot IP when connected to WIMZ hotspot
  static const String defaultHotspotIp = '192.168.4.1';

  /// Common local IP patterns to scan
  static const List<String> _commonSubnets = [
    '192.168.1.',
    '192.168.0.',
    '192.168.4.',
    '10.0.0.',
  ];

  /// Connect directly to robot at known IP
  Future<bool> connectDirect(String ip, [int port = 8000]) async {
    rprint('LocalConnection: Connecting to $ip:$port');
    state = state.copyWith(
      state: LocalConnectionState.connecting,
      robotIp: ip,
      port: port,
      clearError: true,
    );

    try {
      // Configure Dio for local connection
      final baseUrl = 'http://$ip:$port';
      DioClient.setBaseUrl(baseUrl);

      // Test connection with health check
      final isHealthy = await _checkHealth(ip, port);
      if (!isHealthy) {
        state = state.copyWith(
          state: LocalConnectionState.error,
          errorMessage: 'Robot not responding at $ip:$port',
        );
        return false;
      }

      // Connect WebSocket directly to robot
      final wsUrl = 'ws://$ip:$port/ws';
      rprint('LocalConnection: Connecting WebSocket to $wsUrl');
      await WebSocketClient.instance.connect(wsUrl);

      // Set target device - in local mode, we use a generic ID
      WebSocketClient.instance.setTargetDevice('local_robot');

      state = state.copyWith(
        state: LocalConnectionState.connected,
        robotIp: ip,
        port: port,
      );

      rprint('LocalConnection: Connected successfully to $ip:$port');
      return true;
    } catch (e) {
      rprint('LocalConnection: Connection failed: $e');
      state = state.copyWith(
        state: LocalConnectionState.error,
        errorMessage: 'Failed to connect: $e',
      );
      return false;
    }
  }

  /// Connect to robot via WIMZ hotspot (default 192.168.4.1)
  Future<bool> connectViaHotspot() async {
    return connectDirect(defaultHotspotIp);
  }

  /// Scan local network for robots
  Future<void> scanNetwork() async {
    rprint('LocalConnection: Starting network scan');
    state = state.copyWith(
      state: LocalConnectionState.scanning,
      discoveredDevices: [],
      clearError: true,
    );

    final discovered = <String>[];

    // Try common subnets
    for (final subnet in _commonSubnets) {
      // Scan common device IPs (1-20, 100-110, 200-210)
      final ipsToTry = [
        ...List.generate(20, (i) => '$subnet${i + 1}'),
        ...List.generate(10, (i) => '$subnet${i + 100}'),
        ...List.generate(10, (i) => '$subnet${i + 200}'),
        '${subnet}254', // Router often here
      ];

      // Scan in parallel batches
      final futures = <Future<String?>>[];
      for (final ip in ipsToTry) {
        futures.add(_checkRobotAt(ip));
      }

      final results = await Future.wait(futures);
      discovered.addAll(results.whereType<String>());

      // Update state with progress
      if (discovered.isNotEmpty) {
        state = state.copyWith(discoveredDevices: List.from(discovered));
      }
    }

    rprint('LocalConnection: Scan complete, found ${discovered.length} devices');
    state = state.copyWith(
      state: discovered.isEmpty
          ? LocalConnectionState.disconnected
          : LocalConnectionState.disconnected,
      discoveredDevices: discovered,
    );
  }

  /// Check if a robot is at the given IP
  Future<String?> _checkRobotAt(String ip, [int port = 8000]) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      await socket.close();

      // Port is open, now check if it's actually a WIM-Z robot
      if (await _checkHealth(ip, port)) {
        rprint('LocalConnection: Found robot at $ip:$port');
        return ip;
      }
    } catch (e) {
      // Connection failed - not a robot here
    }
    return null;
  }

  /// Check robot health endpoint
  Future<bool> _checkHealth(String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/health'),
      );
      final response = await request.close();
      client.close(force: true);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from local robot
  Future<void> disconnect() async {
    rprint('LocalConnection: Disconnecting');
    _scanTimer?.cancel();
    await WebSocketClient.instance.disconnect();
    state = const LocalConnectionData();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}
