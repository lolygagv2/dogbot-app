import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/environment.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/websocket_client.dart';
import '../../data/datasources/robot_api.dart';

/// Connection state enum
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Connection state data
class ConnectionState {
  final ConnectionStatus status;
  final String? host;
  final int? port;
  final String? errorMessage;
  final bool isDemoMode;
  final String? deviceId; // Robot device ID for cloud connections

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.host,
    this.port,
    this.errorMessage,
    this.isDemoMode = false,
    this.deviceId,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? host,
    int? port,
    String? errorMessage,
    bool? isDemoMode,
    String? deviceId,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      host: host ?? this.host,
      port: port ?? this.port,
      errorMessage: errorMessage,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected || isDemoMode;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => status == ConnectionStatus.error;

  String get baseUrl => AppConfig.baseUrl(host ?? AppConstants.defaultHost, port);
  String get wsUrl => AppConfig.wsUrl(host ?? AppConstants.defaultHost, port);
  String get streamUrl => AppConfig.videoStreamUrl(host ?? AppConstants.defaultHost, port);
}

/// Provider for connection state
final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier(ref);
});

/// Connection state notifier
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  ConnectionNotifier(this._ref) : super(const ConnectionState()) {
    _loadSavedConnection();
  }

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString(AppConstants.keyServerHost);
    final savedPort = prefs.getInt(AppConstants.keyServerPort);

    if (savedHost != null) {
      state = state.copyWith(
        host: savedHost,
        port: savedPort ?? AppConstants.defaultPort,
      );
    }
  }

  Future<void> _saveConnection(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyServerHost, host);
    await prefs.setInt(AppConstants.keyServerPort, port);
    await prefs.setString(
        AppConstants.keyLastConnected, DateTime.now().toIso8601String());
  }

  /// Connect to WIM-Z robot
  Future<bool> connect(String host, [int port = 8000]) async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      host: host,
      port: port,
      errorMessage: null,
    );

    try {
      // Configure Dio client
      final baseUrl = AppConfig.baseUrl(host, port);
      DioClient.setBaseUrl(baseUrl);

      // Test REST connection
      final api = _ref.read(robotApiProvider);
      final isHealthy = await api.healthCheck();

      if (!isHealthy) {
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Server not responding',
        );
        return false;
      }

      // Connect WebSocket
      final ws = _ref.read(websocketClientProvider);
      await ws.connect(AppConfig.wsUrl(host, port));

      // Listen for WebSocket state changes
      _wsSubscription?.cancel();
      _wsSubscription = ws.stateStream.listen((wsState) {
        if (wsState == WsConnectionState.error ||
            wsState == WsConnectionState.disconnected) {
          if (state.status == ConnectionStatus.connected) {
            state = state.copyWith(
              status: ConnectionStatus.error,
              errorMessage: 'WebSocket disconnected',
            );
          }
        }
      });

      // Save successful connection
      await _saveConnection(host, port);

      state = state.copyWith(status: ConnectionStatus.connected);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Disconnect from robot
  Future<void> disconnect() async {
    _wsSubscription?.cancel();
    await _ref.read(websocketClientProvider).disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: null,
    );
  }

  /// Retry connection with saved settings
  Future<bool> reconnect() async {
    if (state.host != null) {
      return connect(state.host!, state.port ?? AppConstants.defaultPort);
    }
    return false;
  }

  /// Enable demo mode - simulate connected state without real robot
  void enableDemoMode() {
    state = state.copyWith(
      status: ConnectionStatus.connected,
      isDemoMode: true,
      host: 'demo',
      port: 0,
      errorMessage: null,
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Convenience provider for checking if connected
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});
