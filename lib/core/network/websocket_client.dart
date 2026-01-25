import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../utils/remote_logger.dart';

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
  final String type;
  final Map<String, dynamic> data;

  WsEvent({required this.type, required this.data});

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    // Use 'type' as primary, fall back to 'event' for backward compatibility
    final messageType = json['type'] as String? ?? json['event'] as String?;

    // Data can be nested in 'data' field OR at top level
    // Robot sends: {"type": "battery", "level": 95, "charging": true}
    // Or relay sends: {"type": "battery", "data": {"level": 95, "charging": true}}
    Map<String, dynamic> eventData;
    if (json.containsKey('data') && json['data'] is Map) {
      eventData = json['data'] as Map<String, dynamic>;
    } else {
      // Use entire message as data (excluding type/event fields)
      eventData = Map<String, dynamic>.from(json)
        ..remove('type')
        ..remove('event');
    }

    return WsEvent(
      type: messageType ?? 'unknown',
      data: eventData,
    );
  }
}

/// Provider for WebSocket client
final websocketClientProvider = Provider<WebSocketClient>((ref) {
  return WebSocketClient();
});

/// WebSocket client for real-time communication with WIM-Z
class WebSocketClient {
  // Singleton instance
  static final WebSocketClient _instance = WebSocketClient._internal();
  static WebSocketClient get instance => _instance;
  factory WebSocketClient() => _instance;
  WebSocketClient._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentUrl;
  String? _targetDeviceId;
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

  // Device status stream (for auto-reconnect when device comes online)
  final _deviceStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Photo capture stream
  final _photoController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get webrtcCredentialsStream =>
      _webrtcCredentialsController.stream;
  Stream<Map<String, dynamic>> get webrtcOfferStream =>
      _webrtcOfferController.stream;
  Stream<Map<String, dynamic>> get webrtcIceStream =>
      _webrtcIceController.stream;
  Stream<Map<String, dynamic>> get webrtcCloseStream =>
      _webrtcCloseController.stream;
  Stream<Map<String, dynamic>> get deviceStatusStream =>
      _deviceStatusController.stream;
  Stream<Map<String, dynamic>> get photoStream =>
      _photoController.stream;

  /// Get the current target device ID
  String? get targetDeviceId => _targetDeviceId;

  /// Set the target device ID for all commands
  void setTargetDevice(String deviceId) {
    _targetDeviceId = deviceId;
    print('WebSocket: Target device set to $deviceId');
  }

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

      // Flush any pending remote logs
      RemoteLogger.onConnected();

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
      final msgType = json['type'] as String? ?? json['event'] as String?;

      // Debug: log ALL messages to find battery data
      print('WS MSG [$msgType]: $json');

      // Check if message contains battery data regardless of type
      if (json.containsKey('level') || json.containsKey('battery')) {
        print('WS BATTERY FOUND in message: $json');
      }

      switch (msgType) {
        // WebRTC signaling messages
        case 'webrtc_credentials':
          _webrtcCredentialsController.add(json);
          break;
        case 'webrtc_offer':
          _webrtcOfferController.add(json);
          break;
        case 'webrtc_ice':
          _webrtcIceController.add(json);
          break;
        case 'webrtc_close':
          _webrtcCloseController.add(json);
          break;

        // Photo capture response
        case 'photo':
          print('WebSocket: Received photo response, keys: ${json.keys}');
          print('WebSocket: Photo data length: ${(json['data'] as String?)?.length ?? 0}');
          _photoController.add(json);
          break;

        // Device status - emit to dedicated stream AND event stream
        case 'device_status':
          _deviceStatusController.add(json);
          final event = WsEvent.fromJson(json);
          _eventController.add(event);
          break;

        // Status response from get_status request
        case 'status_response':
          print('WS: Received status_response: $json');
          _deviceStatusController.add(json);
          final statusResponseEvent = WsEvent.fromJson(json);
          _eventController.add(statusResponseEvent);
          break;

        // Status update from robot (mode, battery, telemetry combined)
        case 'status_update':
          print('WS: Received status_update: $json');
          // Forward to both device status and event streams
          _deviceStatusController.add(json);
          final statusUpdateEvent = WsEvent.fromJson(json);
          _eventController.add(statusUpdateEvent);
          break;

        // Robot events - forward to event stream
        case 'telemetry':
        case 'status':
        case 'robot_status':
        case 'detection':
        case 'battery':
        case 'mode':
        case 'treat':
          final statusEvent = WsEvent.fromJson(json);
          _eventController.add(statusEvent);
          break;

        // Bark event - forward as guardian event for event feed
        case 'bark':
          final barkEvent = WsEvent(
            type: 'event',
            data: {
              'event_type': 'barking',
              'timestamp': DateTime.now().toIso8601String(),
              'details': json['details'] ?? json['message'] ?? 'Bark detected',
              ...json,
            },
          );
          _eventController.add(barkEvent);
          // Also forward original for telemetry provider
          _eventController.add(WsEvent.fromJson(json));
          break;

        // Error messages - only log critical ones
        case 'error':
          final code = json['code'] as String?;
          // Ignore transient errors that don't affect operation
          if (code != 'NOT_AUTHORIZED' && code != 'NO_DEVICE') {
            print('WebSocket error: ${json['message']} ($code)');
          }
          // Still forward to event stream for UI handling if needed
          final event = WsEvent.fromJson(json);
          _eventController.add(event);
          break;

        // Command acknowledgments and responses
        case 'pong':
        case 'ack':
        case 'command_ack':
        case 'response':
          // Commands acknowledged - good, no need to log
          break;

        default:
          // Forward any other typed messages to event stream
          if (msgType != null) {
            final event = WsEvent.fromJson(json);
            _eventController.add(event);
          } else if (json.containsKey('level')) {
            // Untyped message with 'level' key = battery data from robot
            final event = WsEvent(type: 'battery', data: json);
            _eventController.add(event);
          } else {
            print('WebSocket received untyped message: $json');
          }
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
      final json = jsonEncode(data);
      print('WS SEND: $json');
      _channel?.sink.add(json);
    } catch (e) {
      print('WebSocket send error: $e');
    }
  }

  /// Send a command to the robot via relay
  /// Format: {"type": "command", "device_id": "<id>", "command": "<cmd>", "data": {...}}
  void sendCommand(String command, [Map<String, dynamic>? data]) {
    if (_targetDeviceId == null) {
      print('WebSocket: Cannot send command - no target device set');
      return;
    }
    send({
      'type': 'command',
      'device_id': _targetDeviceId,
      'command': command,
      'data': data ?? {},
    });
  }

  /// Send motor command
  void sendMotorCommand(double left, double right) {
    sendCommand('motor', {'left': left, 'right': right});
  }

  /// Send emergency stop
  void sendEmergencyStop() {
    sendCommand('emergency_stop');
  }

  /// Send mode change command
  /// Format: {"type": "command", "device_id": "<id>", "command": "set_mode", "data": {"mode": "<mode>"}}
  void sendModeCommand(String mode) {
    sendCommand('set_mode', {'mode': mode});
  }

  /// Send servo command
  void sendServoCommand(double pan, double tilt) {
    sendCommand('servo', {'pan': pan, 'tilt': tilt});
  }

  /// Center camera servos
  void sendServoCenter() {
    sendCommand('servo_center');
  }

  /// Send treat command
  /// Format: {"type":"command","command":"dispense_treat"}
  void sendTreatCommand() {
    sendCommand('dispense_treat');
  }

  /// Rotate treat carousel
  void sendCarouselRotate() {
    sendCommand('carousel_rotate');
  }

  /// Send LED pattern command
  void sendLedCommand(String pattern) {
    sendCommand('led', {'pattern': pattern});
  }

  /// Send LED color command
  void sendLedColor(int r, int g, int b) {
    sendCommand('led_color', {'r': r, 'g': g, 'b': b});
  }

  /// Turn off LEDs
  void sendLedOff() {
    sendCommand('led_off');
  }

  /// Send audio play command
  void sendAudioCommand(String file) {
    sendCommand('audio', {'file': file});
  }

  /// Stop audio playback
  void sendAudioStop() {
    sendCommand('audio_stop');
  }

  /// Set audio volume
  void sendAudioVolume(int level) {
    sendCommand('audio_volume', {'level': level});
  }

  /// Load next audio track (does NOT auto-play)
  void sendAudioNext() {
    sendCommand('audio_next');
  }

  /// Load previous audio track (does NOT auto-play)
  void sendAudioPrev() {
    sendCommand('audio_prev');
  }

  /// Toggle audio play/pause
  /// If stopped: starts playback
  /// If playing: pauses playback
  void sendAudioToggle() {
    sendCommand('audio_toggle');
  }

  /// Take a photo with optional HUD overlay
  void sendTakePhoto({bool withHud = true}) {
    print('WebSocket: sendTakePhoto called with withHud=$withHud');
    print('WebSocket: targetDeviceId=$_targetDeviceId, state=$_state');
    sendCommand('take_photo', {'with_hud': withHud});
    print('WebSocket: take_photo command sent');
  }

  /// Upload a voice command recording to the robot
  void sendVoiceCommand(String commandId, String base64Data) {
    sendCommand('upload_voice', {
      'name': commandId,
      'data': base64Data,
    });
  }

  /// Send audio message to robot (push-to-talk)
  void sendAudioMessage(String base64Data, String format, int durationMs) {
    send({
      'type': 'audio_message',
      'data': base64Data,
      'format': format,
      'duration_ms': durationMs,
    });
  }

  /// Request audio from robot (listen)
  void requestAudioFromRobot(int durationSeconds) {
    send({
      'type': 'audio_request',
      'duration': durationSeconds,
    });
  }

  /// Request WebRTC video stream
  void requestVideoStream() {
    send({'type': 'webrtc_request'});
  }

  /// Send WebRTC answer
  void sendWebrtcAnswer(Map<String, dynamic> answer) {
    send({'type': 'webrtc_answer', ...answer});
  }

  /// Send WebRTC ICE candidate
  void sendWebrtcIce(Map<String, dynamic> candidate) {
    send({'type': 'webrtc_ice', ...candidate});
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
    _deviceStatusController.close();
    _photoController.close();
  }
}
