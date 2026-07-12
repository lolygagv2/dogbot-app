import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/environment.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/session/session_id.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/jwt_decode.dart';
import '../../data/datasources/robot_api.dart';
import 'auth_provider.dart';
import 'device_provider.dart';
import 'notifications_provider.dart';

/// 3-tier connection state - honest about what's actually connected
enum ConnectionStatus {
  disconnected,     // No relay connection
  connecting,       // Attempting to connect to relay
  relayConnected,   // WebSocket to relay open, waiting for robot status
  robotOnline,      // Robot is connected to relay AND responding
  error,            // Connection error
  superseded,       // B1: This session was kicked by a newer login on the same account/device
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
  bool get isSuperseded => status == ConnectionStatus.superseded;

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
      case ConnectionStatus.superseded:
        return 'Signed in on another device';
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
  StreamSubscription? _supersededSubscription; // B1
  StreamSubscription? _closeReasonSubscription; // Fix #2
  Timer? _reconnectTimer;
  Timer? _statusCheckTimer;
  Timer? _statusDowngradeTimer; // Build 34: Debounce status downgrades
  static const Duration _statusCheckInterval = Duration(seconds: 30);
  // Build 34: Grace period before showing "Waiting for robot" after being online
  static const Duration _statusDowngradeDelay = Duration(milliseconds: 1500);

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
    connTrace('conn-begin', 'host=$host port=$port');
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
        connTrace('health-fail', '$baseUrl/health');
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Server not responding',
        );
        return false;
      }
      connTrace('health-ok', baseUrl);

      // Get auth token for WebSocket connection
      final authState = _ref.read(authProvider);
      final token = authState.token;

      // B1: regenerate session id for this fresh connection. Old sessions for
      // the same (user, device) on the relay will be superseded.
      final newSessionId = SessionId.regenerate();

      // Connect WebSocket
      final ws = _ref.read(websocketClientProvider);
      final wsUrl = token != null
          ? AppConfig.wsUrlWithToken(host, token, port)
          : AppConfig.wsUrl(host, port);
      // Build 101: on cold open, both _loadSavedAuth and DeviceIdNotifier's
      // _loadDeviceId start async at the same time. If we read deviceIdProvider
      // before the prefs load completes, we get the synchronous default
      // ("wimz_robot_01") and bind the relay session to the wrong robot for
      // the rest of the session — TestFlight logs caught this firing at
      // 17:15:05.168 (webrtc-request-sent device=wimz_robot_01) before the WS
      // was even open. Awaiting here guarantees session_hello carries the
      // user's actual saved device.
      await _ref.read(deviceIdProvider.notifier).loadReady;
      final deviceId = _ref.read(deviceIdProvider);
      // Build 90: extract user_id from the JWT `sub` claim. The relay
      // validates session_hello.user_id against this (e.g. `user_000042`,
      // not email). Falls back to authState.userId / email if the token
      // is malformed for some reason.
      final sessionUserId =
          jwtSub(token) ?? authState.userId ?? authState.email;
      print('Connecting WebSocket to: $wsUrl (session=$newSessionId, user=$sessionUserId)');
      connTrace('ws-connect-attempt',
          'user=$sessionUserId device=$deviceId hasToken=${token != null}');
      await ws.connect(
        wsUrl,
        sessionId: newSessionId,
        userId: sessionUserId,
        deviceId: deviceId,
      );

      // Set target device ID
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

      // B1: listen for relay supersede notice
      _supersededSubscription?.cancel();
      _supersededSubscription =
          ws.sessionSupersededStream.listen(_onSessionSuperseded);

      // Fix #2: close-reason stream — drives permanent-close routing
      // (re-login / superseded) without a second reconnect loop.
      _closeReasonSubscription?.cancel();
      _closeReasonSubscription =
          ws.closeReasonStream.listen(_onWsCloseReason);

      // ws.connect() returns normally even when the handshake failed (its
      // _doConnect catches the error and schedules its own retries), so
      // falling through here used to persist the host and claim
      // relayConnected on a socket that never opened — which is how a robot
      // IP got written to server_host and hijacked every later cloud
      // connect. Listeners above stay attached: if a background retry
      // succeeds, _onWsStateChange upgrades the state from error.
      if (ws.state != WsConnectionState.connected) {
        connTrace('conn-ws-failed', 'wsState=${ws.state} — host not saved');
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Could not open live connection to server',
        );
        return false;
      }

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
      connTrace('conn-error', '$e');
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void _onWsStateChange(WsConnectionState wsState) {
    if (wsState == WsConnectionState.connected) {
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
      // Fix #2: WebSocketClient owns reconnection now — retryable close
      // codes only, exponential backoff. A second reconnect loop here was
      // half the reconnect storm. Permanent-close routing is handled by
      // _onWsCloseReason.
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Lost connection to server',
      );
    }
  }

  /// Fix #2: WebSocketClient classified the WS close code. Permanent codes
  /// must not be retried — route them to the correct terminal UI.
  void _onWsCloseReason(WsCloseReason reason) {
    print('Connection: WS close reason = $reason');
    switch (reason) {
      case WsCloseReason.retryable:
        // WebSocketClient is already retrying with backoff — nothing to do.
        break;
      case WsCloseReason.cleanClose:
        // App-initiated close — quiet.
        break;
      case WsCloseReason.superseded:
        // 4003: another app instance took over. Same handling as the
        // session_superseded message — non-fatal banner, no reconnect.
        _onSessionSuperseded(const <String, dynamic>{'by': 'another device'});
        break;
      case WsCloseReason.malformedHandshake:
        // 4000: should not happen after Fix #1. Permanent — surface, no retry.
        _reconnectTimer?.cancel();
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Connection handshake failed. Please update the app.',
        );
        break;
      case WsCloseReason.invalidToken:
        // 4001: the stored token is invalid/expired — force re-login. The
        // notice survives the logout() reset so /login can explain why the
        // user was bounced.
        _reconnectTimer?.cancel();
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Session expired — please sign in again.',
        );
        _ref.read(authProvider.notifier).logout(
              notice: 'Your session expired — please sign in again.',
            );
        break;
    }
  }

  void _onDeviceStatus(Map<String, dynamic> status) {
    final deviceId = status['device_id'] as String?;
    final currentDeviceId = _ref.read(deviceIdProvider);

    // Only process status for our current device
    if (deviceId != null && deviceId != currentDeviceId) {
      print('Connection: Ignoring status for $deviceId (current: $currentDeviceId)');
      return;
    }

    // Handle robot_online field from relay status_response
    final isOnline = status['robot_online'] as bool? ??
                     status['online'] as bool? ??
                     status['is_online'] as bool? ??
                     false;
    final isPaired = status['device_paired'] as bool? ??
                     status['paired'] as bool? ??
                     true; // Assume paired if not specified

    print('Connection: Device ${deviceId ?? currentDeviceId} - robot_online=$isOnline, device_paired=$isPaired');

    if (!isPaired) {
      _statusDowngradeTimer?.cancel();
      state = state.copyWith(
        status: ConnectionStatus.relayConnected,
        pairingStatus: PairingStatus.notPaired,
      );
    } else if (isOnline) {
      // Cancel any pending downgrade when robot comes online
      _statusDowngradeTimer?.cancel();
      state = state.copyWith(
        status: ConnectionStatus.robotOnline,
        pairingStatus: PairingStatus.paired,
        lastRobotSeen: DateTime.now(),
        errorMessage: null,
      );
    } else {
      // Build 34: Debounce downgrade from robotOnline to relayConnected
      // This prevents brief "Waiting for robot" flashes
      if (state.status == ConnectionStatus.robotOnline) {
        print('Connection: Robot went offline, starting grace period');
        _statusDowngradeTimer?.cancel();
        _statusDowngradeTimer = Timer(_statusDowngradeDelay, () {
          if (mounted && state.status == ConnectionStatus.robotOnline) {
            print('Connection: Grace period expired, showing "Waiting for robot"');
            state = state.copyWith(
              status: ConnectionStatus.relayConnected,
              pairingStatus: PairingStatus.paired,
            );
          }
        });
      } else {
        state = state.copyWith(
          status: ConnectionStatus.relayConnected,
          pairingStatus: PairingStatus.paired,
        );
      }
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
    _statusDowngradeTimer?.cancel();
    _wsStateSubscription?.cancel();
    _wsEventSubscription?.cancel();
    _deviceStatusSubscription?.cancel();
    _supersededSubscription?.cancel();
    _closeReasonSubscription?.cancel();
    await _ref.read(websocketClientProvider).disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      pairingStatus: PairingStatus.unknown,
      isDemoMode: false,
      errorMessage: null,
    );
  }

  /// B1: Relay told us this session has been superseded by a newer login.
  /// Tear down WS + WebRTC and surface a non-fatal banner. The user can pull
  /// to refresh / tap a button to take control back, which will create a new
  /// session id and supersede the other device.
  void _onSessionSuperseded(Map<String, dynamic> payload) {
    print('Connection: session_superseded by=${payload['by']}');
    _reconnectTimer?.cancel();
    _statusCheckTimer?.cancel();
    _statusDowngradeTimer?.cancel();
    // WebRTC teardown happens via webrtc_provider listening to connection state.
    // We deliberately do NOT call disconnect() here so the host/port stay set
    // (allowing the user to tap "take over" and reconnect with a new session).
    state = state.copyWith(
      status: ConnectionStatus.superseded,
      errorMessage:
          'This account is now active on another device. Tap to take control back.',
    );
  }

  /// B1: User opted to take control back from the other device. Generates a
  /// new session id and reconnects, which will supersede the other session.
  Future<bool> takeOverSession() async {
    if (state.host == null) return false;
    return connect(state.host!, state.port ?? AppConstants.defaultPort);
  }

  /// Retry connection with saved settings
  Future<bool> reconnect() async {
    if (state.host != null) {
      return connect(state.host!, state.port ?? AppConstants.defaultPort);
    }
    return false;
  }

  /// Schedule auto-reconnect with exponential backoff
  /// Called when app resumes from background (phone lock, task switch)
  /// Resets reconnect counters and attempts to restore connection
  void onAppResumed() {
    print('Connection: App resumed — checking connection state');
    final ws = _ref.read(websocketClientProvider);
    ws.resetReconnectAttempts();

    if (state.isDemoMode) return;

    // Build 125: refresh activity/SG history on resume. The 7-day REST hydrate
    // previously ran ONLY at login, so backgrounding for hours then reopening
    // showed no new events (the 2-hour-gap bug). notificationsProvider is the
    // single history source now, so the SG feed updates from this too.
    // Self-skips in local mode / when no token is available.
    _ref.read(notificationsProvider.notifier).hydrateFromRelay();

    // Don't attempt relay reconnect if WebSocket is already connected
    // (e.g., local mode has its own active connection)
    if (ws.state == WsConnectionState.connected) {
      print('Connection: WebSocket already connected (likely local mode), skipping relay reconnect');
      if (state.isRelayConnected) {
        _requestRobotStatus();
      }
      return;
    }

    if (!state.isRelayConnected && state.host != null) {
      print('Connection: Not connected, attempting reconnect');
      reconnect();
    } else if (state.isRelayConnected) {
      print('Connection: Already connected, requesting robot status');
      _requestRobotStatus();
    }
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

  /// Mark as connected in local mode — no relay, no auth, direct to Pi.
  /// This makes connectionProvider.isConnected return true so all controls work.
  /// A-DISCOVER: takes the IP that actually won the connect race — the robot
  /// may be on home WiFi, not just the 192.168.4.1 AP.
  void setLocalConnected([String host = '192.168.4.1', int port = 8000]) {
    state = state.copyWith(
      status: ConnectionStatus.robotOnline,
      pairingStatus: PairingStatus.paired,
      host: host,
      port: port,
      errorMessage: null,
    );
    print('Connection: Set to local connected (robot online at $host:$port)');
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
    _statusDowngradeTimer?.cancel();
    super.dispose();
  }
}

/// Convenience provider for checking if robot is actually online
/// Returns true for EITHER relay connection OR local direct connection
final isRobotOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRobotOnline ||
      ref.watch(localConnectionProvider).isConnected;
});

/// Convenience provider for checking if at least relay connected
final isRelayConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRelayConnected ||
      ref.watch(localConnectionProvider).isConnected;
});

/// Legacy alias - prefer isRobotOnlineProvider
/// Returns true for EITHER relay OR local connection
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isRobotOnline ||
      ref.watch(localConnectionProvider).isConnected;
});

/// Stream provider for rate limit errors from relay
final rateLimitProvider = StreamProvider<String>((ref) {
  return ref.read(websocketClientProvider).rateLimitStream;
});
