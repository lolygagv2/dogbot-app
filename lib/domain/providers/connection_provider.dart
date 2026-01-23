import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/environment.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/websocket_client.dart';
import '../../data/datasources/robot_api.dart';
import 'auth_provider.dart';
import 'device_provider.dart';

/// 3-tier connection state - honest about what's actually connected
enum ConnectionStatus {
  disconnected,     // No relay connection
  connecting,       // Attempting to connect to relay
  relayConnected,   // WebSocket to relay open, waiting for robot status
  robotOnline,      // Robot is connected to relay AND responding
  error,            // Connection error
}

/// Robot pairing status
enum PairingStatus {
  unknown,          // Haven't checked yet
  notPaired,        // Device not paired to this user
  paired,           // Device is paired
}

/// Connection state data
class ConnectionState {
  final ConnectionStatus status;
  final PairingStatus pairingStatus;
  final String? host;
  final int? port;
  final String? errorMessage;
  final bool isDemoMode;
  final String? deviceId;
  final DateTime? lastRobotSeen;

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.pairingStatus = PairingStatus.unknown,
    this.host,
    this.port,
    this.errorMessage,
    this.isDemoMode = false,
    this.deviceId,
    this.lastRobotSeen,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    PairingStatus? pairingStatus,
    String? host,
    int? port,
    String? errorMessage,
    bool? isDemoMode,
    String? deviceId,
    DateTime? lastRobotSeen,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      pairingStatus: pairingStatus ?? this.pairingStatus,
      host: host ?? this.host,
      port: port ?? this.port,
      errorMessage: errorMessage,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      deviceId: deviceId ?? this.deviceId,
      lastRobotSeen: lastRobotSeen ?? this.lastRobotSeen,
    );
  }

  /// True only when robot is actually online and responding
  bool get isRobotOnline => status == ConnectionStatus.robotOnline || isDemoMode;

  /// Legacy alias for isRobotOnline - use isRobotOnline for clarity
  bool get isConnected => isRobotOnline;

  /// True when at least connected to relay
  bool get isRelayConnected =>
      status == ConnectionStatus.relayConnected ||
      status == ConnectionStatus.robotOnline ||
      isDemoMode;

  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => status == ConnectionStatus.error;
  bool get isNotPaired => pairingStatus == PairingStatus.notPaired;

  /// Human-readable status message
  String get statusMessage {
    if (isDemoMode) return 'Demo Mode';
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting to server...';
      case ConnectionStatus.relayConnected:
        if (pairingStatus == PairingStatus.notPaired) {
          return 'Device not paired';
        }
        return 'Server connected. Waiting for robot...';
      case ConnectionStatus.robotOnline:
        return 'Robot online';
      case ConnectionStatus.error:
        return errorMessage ?? 'Connection error';
    }
  }

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
  StreamSubscription? _wsStateSubscription;
  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _deviceStatusSubscription;
  Timer? _reconnectTimer;
  Timer? _statusCheckTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _statusCheckInterval = Duration(seconds: 30);

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

  /// Connect to WIM-Z relay server
  Future<bool> connect(String host, [int port = 8000]) async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      pairingStatus: PairingStatus.unknown,
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

      // Get auth token for WebSocket connection
      final authState = _ref.read(authProvider);
      final token = authState.token;

      // Connect WebSocket
      final ws = _ref.read(websocketClientProvider);
      final wsUrl = token != null
          ? AppConfig.wsUrlWithToken(host, token, port)
          : AppConfig.wsUrl(host, port);
      print('Connecting WebSocket to: $wsUrl');
      await ws.connect(wsUrl);

      // Set target device ID
      final deviceId = _ref.read(deviceIdProvider);
      ws.setTargetDevice(deviceId);
      state = state.copyWith(deviceId: deviceId);
      print('Connection: Target device set to $deviceId');

      // Listen for WebSocket state changes
      _wsStateSubscription?.cancel();
      _wsStateSubscription = ws.stateStream.listen(_onWsStateChange);

      // Listen for robot status events
      _deviceStatusSubscription?.cancel();
      _deviceStatusSubscription = ws.deviceStatusStream.listen(_onDeviceStatus);

      // Listen for error events (command responses)
      _wsEventSubscription?.cancel();
      _wsEventSubscription = ws.eventStream.listen(_onWsEvent);

      // Save connection settings
      await _saveConnection(host, port);

      // Mark as relay connected (not robot online yet!)
      state = state.copyWith(status: ConnectionStatus.relayConnected);

      // Request robot status immediately
      _requestRobotStatus();

      // Start periodic status checks
      _startStatusChecks();

      return true;
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void _onWsStateChange(WsConnectionState wsState) {
    if (wsState == WsConnectionState.connected) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      // Only upgrade to relayConnected, not robotOnline
      if (state.status == ConnectionStatus.disconnected ||
          state.status == ConnectionStatus.connecting ||
          state.status == ConnectionStatus.error) {
        state = state.copyWith(
          status: ConnectionStatus.relayConnected,
          errorMessage: null,
        );
        // Request robot status
        _requestRobotStatus();
      }
    } else if (wsState == WsConnectionState.reconnecting) {
      print('Connection: WebSocket reconnecting...');
      // Keep current status but note we're reconnecting
    } else if (wsState == WsConnectionState.error ||
        wsState == WsConnectionState.disconnected) {
      print('Connection: Lost relay connection');
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Lost connection to server',
      );
      _scheduleReconnect();
    }
  }

  void _onDeviceStatus(Map<String, dynamic> status) {
    final deviceId = status['device_id'] as String?;
    final currentDeviceId = _ref.read(deviceIdProvider);

    // Only process status for our current device
    if (deviceId != currentDeviceId) return;

    final isOnline = status['online'] as bool? ??
                     status['is_online'] as bool? ??
                     false;
    final isPaired = status['device_paired'] as bool? ??
                     status['paired'] as bool? ??
                     true; // Assume paired if not specified

    print('Connection: Device $deviceId - online=$isOnline, paired=$isPaired');

    if (!isPaired) {
      state = state.copyWith(
        status: ConnectionStatus.relayConnected,
        pairingStatus: PairingStatus.notPaired,
      );
    } else if (isOnline) {
      state = state.copyWith(
        status: ConnectionStatus.robotOnline,
        pairingStatus: PairingStatus.paired,
        lastRobotSeen: DateTime.now(),
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        status: ConnectionStatus.relayConnected,
        pairingStatus: PairingStatus.paired,
      );
    }
  }

  void _onWsEvent(WsEvent event) {
    // Handle error responses from commands
    if (event.type == 'error') {
      final code = event.data['code'] as String?;
      final message = event.data['message'] as String?;

      switch (code) {
        case 'DEVICE_NOT_PAIRED':
        case 'NOT_PAIRED':
          state = state.copyWith(
            pairingStatus: PairingStatus.notPaired,
            status: ConnectionStatus.relayConnected,
            errorMessage: 'Device not paired. Go to Settings to pair.',
          );
          break;
        case 'ROBOT_OFFLINE':
        case 'DEVICE_OFFLINE':
          state = state.copyWith(
            status: ConnectionStatus.relayConnected,
            errorMessage: 'Robot is offline',
          );
          break;
        case 'NOT_AUTHORIZED':
          state = state.copyWith(
            errorMessage: 'Not authorized. Please log in again.',
          );
          break;
        default:
          // Don't override status for unknown errors
          if (message != null) {
            print('Connection: Error - $message ($code)');
          }
      }
    }

    // Handle status response
    if (event.type == 'status_response') {
      _onDeviceStatus(event.data);
    }

    // Handle robot_status broadcasts
    if (event.type == 'robot_status') {
      _onDeviceStatus(event.data);
    }
  }

  /// Request current robot status from relay
  void _requestRobotStatus() {
    final ws = _ref.read(websocketClientProvider);
    final deviceId = _ref.read(deviceIdProvider);

    if (ws.state == WsConnectionState.connected) {
      ws.send({
        'type': 'get_status',
        'device_id': deviceId,
      });
      print('Connection: Requested status for $deviceId');
    }
  }

  void _startStatusChecks() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(_statusCheckInterval, (_) {
      if (state.isRelayConnected) {
        _requestRobotStatus();
      }
    });
  }

  /// Disconnect from relay
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _statusCheckTimer?.cancel();
    _reconnectAttempts = 0;
    _wsStateSubscription?.cancel();
    _wsEventSubscription?.cancel();
    _deviceStatusSubscription?.cancel();
    await _ref.read(websocketClientProvider).disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      pairingStatus: PairingStatus.unknown,
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

  /// Schedule auto-reconnect with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Connection: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(
      milliseconds: _reconnectDelay.inMilliseconds * _reconnectAttempts,
    );

    print('Connection: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      if (state.host != null && !state.isRelayConnected) {
        await reconnect();
      }
    });
  }

  /// Called when device ID changes - re-check robot status
  void onDeviceIdChanged(String newDeviceId) {
    state = state.copyWith(
      deviceId: newDeviceId,
      status: state.isRelayConnected ? ConnectionStatus.relayConnected : state.status,
      pairingStatus: PairingStatus.unknown,
    );

    if (state.isRelayConnected) {
      _requestRobotStatus();
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Enable demo mode - simulate fully connected state
  void enableDemoMode() {
    state = state.copyWith(
      status: ConnectionStatus.robotOnline,
      pairingStatus: PairingStatus.paired,
      isDemoMode: true,
      host: 'demo',
      port: 0,
      errorMessage: null,
    );
  }

  @override
  void dispose() {
    _wsStateSubscription?.cancel();
    _wsEventSubscription?.cancel();
    _deviceStatusSubscription?.cancel();
    _reconnectTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}

/// Convenience provider for checking if robot is actually online
final isRobotOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRobotOnline;
});

/// Convenience provider for checking if at least relay connected
final isRelayConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRelayConnected;
});

/// Legacy alias - prefer isRobotOnlineProvider
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRobotOnline;
});
