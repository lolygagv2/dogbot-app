import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';

/// WebSocket connection state
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket event from the robot
class WsEvent {
  final String event;
  final Map<String, dynamic> data;

  WsEvent({required this.event, required this.data});

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      event: json['event'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Provider for WebSocket client
final websocketClientProvider = Provider<WebSocketClient>((ref) {
  return WebSocketClient();
});

/// WebSocket client for real-time communication with WIM-Z
class WebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentUrl;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  final _stateController = StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  final _eventController = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get eventStream => _eventController.stream;

  // WebRTC signaling streams
  final _webrtcCredentialsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcIceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcCloseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get webrtcCredentialsStream =>
      _webrtcCredentialsController.stream;
  Stream<Map<String, dynamic>> get webrtcOfferStream =>
      _webrtcOfferController.stream;
  Stream<Map<String, dynamic>> get webrtcIceStream =>
      _webrtcIceController.stream;
  Stream<Map<String, dynamic>> get webrtcCloseStream =>
      _webrtcCloseController.stream;

  /// Connect to WebSocket server
  Future<void> connect(String url) async {
    if (_state == WsConnectionState.connected && _currentUrl == url) {
      return; // Already connected to this URL
    }

    await disconnect();
    _currentUrl = url;
    _reconnectAttempts = 0;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentUrl == null) return;

    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));

      // Wait for connection to establish
      await _channel!.ready;

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Start ping timer
      _startPingTimer();
    } catch (e) {
      print('WebSocket connection error: $e');
      _setState(WsConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final msgType = json['type'] as String?;

      // Handle WebRTC signaling messages
      if (msgType == 'webrtc_credentials') {
        _webrtcCredentialsController.add(json);
      } else if (msgType == 'webrtc_offer') {
        _webrtcOfferController.add(json);
      } else if (msgType == 'webrtc_ice') {
        _webrtcIceController.add(json);
      } else if (msgType == 'webrtc_close') {
        _webrtcCloseController.add(json);
      } else {
        // Existing event handling
        final event = WsEvent.fromJson(json);
        _eventController.add(event);
      }
    } catch (e) {
      print('WebSocket message parse error: $e');
    }
  }

  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _setState(WsConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    print('WebSocket closed');
    if (_state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnect attempts reached');
      _setState(WsConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    _setState(WsConnectionState.reconnecting);

    final delay = Duration(
      milliseconds: AppConstants.websocketReconnectDelay.inMilliseconds *
          _reconnectAttempts,
    );

    print('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.websocketPingInterval, (_) {
      if (_state == WsConnectionState.connected) {
        send({'type': 'ping'});
      }
    });
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Send a message to the server
  void send(Map<String, dynamic> data) {
    if (_state != WsConnectionState.connected) {
      print('Cannot send: WebSocket not connected');
      return;
    }

    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      print('WebSocket send error: $e');
    }
  }

  /// Send motor command
  void sendMotorCommand(double left, double right) {
    send({
      'command': 'motor',
      'left': left,
      'right': right,
    });
  }

  /// Send servo command
  void sendServoCommand(double pan, double tilt) {
    send({
      'command': 'servo',
      'pan': pan,
      'tilt': tilt,
    });
  }

  /// Send treat command
  void sendTreatCommand() {
    send({'command': 'treat'});
  }

  /// Send LED pattern command
  void sendLedCommand(String pattern) {
    send({
      'command': 'led',
      'pattern': pattern,
    });
  }

  /// Send audio play command
  void sendAudioCommand(String file) {
    send({
      'command': 'audio',
      'file': file,
    });
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();

    await _channel?.sink.close();
    _channel = null;
    _currentUrl = null;

    _setState(WsConnectionState.disconnected);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _stateController.close();
    _eventController.close();
    _webrtcCredentialsController.close();
    _webrtcOfferController.close();
    _webrtcIceController.close();
    _webrtcCloseController.close();
  }
}
