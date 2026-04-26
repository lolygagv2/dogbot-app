import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../session/session_id.dart';
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
  // B1: identity for session_hello, set by ConnectionNotifier on connect()
  String? _sessionId;
  String? _sessionUserId;
  String? _sessionDeviceId;
  // Build 88: when the relay rejects our session_hello (close 4000) we
  // suppress the handshake on the next reconnect attempt so the user
  // isn't stuck in an infinite handshake-fail / reconnect loop. The
  // relay can still derive user identity from the bearer token alone.
  bool _suppressSessionHello = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  /// The current session id sent with the session_hello frame and tagged on
  /// every signaling frame. Null until [connect] is called.
  String? get sessionId => _sessionId;

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

  // Video capture stream
  final _videoController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Rate limit stream (relay returns RATE_LIMITED error)
  final _rateLimitController = StreamController<String>.broadcast();

  // B1: Session supersede stream — relay closes the prior session for this
  // (user, device) pair when a new one connects. Payload: {by: <new_session_id>}.
  final _sessionSupersededController =
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
  Stream<Map<String, dynamic>> get videoStream =>
      _videoController.stream;
  Stream<String> get rateLimitStream => _rateLimitController.stream;
  Stream<Map<String, dynamic>> get sessionSupersededStream =>
      _sessionSupersededController.stream;

  /// Get the current target device ID
  String? get targetDeviceId => _targetDeviceId;

  /// Set the target device ID for all commands
  void setTargetDevice(String deviceId) {
    _targetDeviceId = deviceId;
    print('WebSocket: Target device set to $deviceId');
  }

  /// Reset reconnect attempt counter (used when app resumes from background)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  /// Connect to WebSocket server.
  ///
  /// [sessionId], [userId], [deviceId] are used to send the B1 `session_hello`
  /// handshake frame as the first message after the WS upgrade succeeds. The
  /// relay validates [userId] against the bearer token and supersedes any
  /// prior session for the same (userId, deviceId) pair.
  Future<void> connect(
    String url, {
    String? sessionId,
    String? userId,
    String? deviceId,
  }) async {
    if (_state == WsConnectionState.connected && _currentUrl == url) {
      return; // Already connected to this URL
    }

    await disconnect();
    _currentUrl = url;
    _sessionId = sessionId ?? SessionId.current;
    _sessionUserId = userId;
    _sessionDeviceId = deviceId;
    // Build 88: a fresh connect() (e.g. user tapped reconnect, took over a
    // superseded session, or logged in fresh) gets a fresh shot at the
    // handshake. We only suppress it within a single connect→reconnect run.
    _suppressSessionHello = false;
    _reconnectAttempts = 0;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentUrl == null) return;

    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));

      // Wait for connection to establish (5-second timeout to avoid hanging)
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _channel?.sink.close();
          _channel = null;
          throw Exception('WebSocket handshake timed out after 5s');
        },
      );

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

      // B1: send session_hello as the first frame so the relay can supersede
      // any prior session for this (user, device) and validate user_id against
      // the bearer token.
      _sendSessionHello();

      // Start ping timer
      _startPingTimer();
    } catch (e) {
      print('WebSocket connection error: $e');
      _setState(WsConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// Check if a message is from the currently targeted robot.
  /// Returns true if the message should be processed, false if it should be skipped.
  /// Messages without an identifier are always accepted (local mode, legacy relay).
  /// Checks both device_id (relay commands) and robot_id (robot events).
  bool _isFromTargetDevice(Map<String, dynamic> json) {
    final nestedData = json['data'];

    // Check device_id (relay format) and robot_id (robot event format)
    final sourceId = json['device_id'] as String? ??
        json['robot_id'] as String? ??
        ((nestedData is Map) ? (nestedData['device_id'] as String? ?? nestedData['robot_id'] as String?) : null);

    if (sourceId == null || _targetDeviceId == null) return true;
    return sourceId == _targetDeviceId;
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
        // B1: relay supersession notice — a new session for this (user, device)
        // has connected and we're being kicked. Surface to the connection
        // provider so it can tear down WS+WebRTC and show a banner.
        case 'session_superseded':
          print('WS: session_superseded received: $json');
          _sessionSupersededController.add(json);
          break;

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

        // Video capture response (robot may send as 'video' or 'video_ready')
        case 'video':
        case 'video_ready':
          print('WebSocket: Received $msgType, keys: ${json.keys}');
          _videoController.add(json);
          break;

        // Recording state events — forward to event stream
        case 'recording_started':
        case 'recording_stopped':
          print('WebSocket: Received $msgType');
          final recEvent = WsEvent.fromJson(json);
          _eventController.add(recEvent);
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
          if (!_isFromTargetDevice(json)) break;
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
        case 'unknown_dog_detected':
        case 'battery':
        case 'mode':
        case 'treat':
        case 'treat_status':
        case 'reward':
          if (!_isFromTargetDevice(json)) break;
          final statusEvent = WsEvent.fromJson(json);
          _eventController.add(statusEvent);
          break;

        // Audio message from robot (listen/PTT response)
        case 'audio_message':
          print('WebSocket: Received audio_message, data length: ${(json['data'] as String?)?.length ?? 0}');
          final audioEvent = WsEvent.fromJson(json);
          _eventController.add(audioEvent);
          break;

        // Mission events - forward to event stream for mode provider
        case 'mission_progress':
        case 'mission_complete':
        case 'mission_stopped':
        case 'mission_status':
        case 'mission_error':
        case 'mission_failed':
          if (!_isFromTargetDevice(json)) break;
          print('WS: Received $msgType: $json');
          final missionEvent = WsEvent.fromJson(json);
          _eventController.add(missionEvent);
          break;

        // Mode changed event (Build 31) - includes locked state
        case 'mode_changed':
          if (!_isFromTargetDevice(json)) break;
          print('WS: Received mode_changed: $json');
          final modeChangedEvent = WsEvent.fromJson(json);
          _eventController.add(modeChangedEvent);
          break;

        // Audio state event (Build 31) - sync music player UI
        case 'audio_state':
          if (!_isFromTargetDevice(json)) break;
          print('WS: Received audio_state: $json');
          final audioStateEvent = WsEvent.fromJson(json);
          _eventController.add(audioStateEvent);
          break;

        // Bark event - forward as guardian event for event feed
        case 'bark':
          if (!_isFromTargetDevice(json)) break;
          final barkEvent = WsEvent(
            type: 'event',
            data: {
              ...json, // Spread robot data first
              // Our overrides AFTER spread so they take precedence:
              'event_type': 'barking',
              'timestamp': DateTime.now().toIso8601String(), // Always use local device time
              'details': json['details'] ?? json['message'] ?? 'Bark detected',
            },
          );
          _eventController.add(barkEvent);
          // Also forward original for telemetry provider
          _eventController.add(WsEvent.fromJson(json));
          break;

        // Error messages - only log critical ones
        case 'error':
          final code = json['code'] as String?;
          // Rate limit: emit to dedicated stream for UI snackbar
          if (code == 'RATE_LIMITED') {
            final msg = json['message'] as String? ?? 'Too many commands, slow down';
            _rateLimitController.add(msg);
          }
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
        case 'command_response':
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
    // B1 diagnostics: surface the close code/reason so we can tell
    // 4000 (bad session_hello), 4001 (superseded), 4002 (heartbeat)
    // apart from a normal disconnect.
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason;
    print('WebSocket closed (code=$code, reason=$reason)');
    if (_state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.disconnected);
      // 4001 — superseded by another session. Don't reconnect; the connection
      // provider has already routed to ConnectionStatus.superseded.
      if (code == 4001) {
        print('WebSocket: superseded by another session, not reconnecting');
        return;
      }
      // 4000 — relay rejected session_hello (handshake mismatch / timeout).
      // Reconnecting with the same payload would just loop. Suppress
      // session_hello on the next attempt so the relay falls back to
      // bearer-token identity. We re-enable on the next connect() call.
      if (code == 4000 && !_suppressSessionHello) {
        print('WebSocket: handshake rejected (4000), suppressing session_hello on retry');
        _suppressSessionHello = true;
      }
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

  /// B1: First frame after the WS upgrade. Relay expects this within 5s or it
  /// closes with 4000.
  ///
  /// Build 88: skipped when [_suppressSessionHello] is set — used after a
  /// 4000 close so we don't keep banging on a handshake the relay rejects.
  void _sendSessionHello() {
    if (_sessionId == null) {
      // Connection started before sessionId/userId/deviceId were set — caller
      // is on the legacy connect() path (e.g. local mode); skip handshake.
      return;
    }
    if (_suppressSessionHello) {
      print('WebSocket: skipping session_hello (suppressed after prior 4000)');
      return;
    }
    send({
      'type': 'session_hello',
      'session_id': _sessionId,
      if (_sessionUserId != null) 'user_id': _sessionUserId,
      if (_sessionDeviceId != null) 'device_id': _sessionDeviceId,
    });
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
  /// Format: {"type": "command", "device_id": "<id>", "command": "<cmd>", "data": {...}, "timestamp": <ms>}
  /// Timestamp allows robot/relay to reject stale commands (>2s old)
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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

  /// Send mode change command (v1.3: includes source and timestamp)
  /// Format: {"type": "command", "device_id": "<id>", "command": "set_mode", "data": {"mode": "<mode>", "source": "<source>", "timestamp": "ISO8601"}}
  void sendModeCommand(String mode, {String source = 'dropdown'}) {
    sendCommand('set_mode', {
      'mode': mode,
      'source': source,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Notify robot that manual control (drive screen) is active
  void sendManualControlActive() {
    sendCommand('set_manual_control', {'active': true});
  }

  /// Notify robot that manual control (drive screen) is inactive
  void sendManualControlInactive() {
    sendCommand('set_manual_control', {'active': false});
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

  /// Set treat counter to a specific count
  void sendTreatCounterSet(int count) {
    sendCommand('treat_counter_set', {'count': count});
  }

  /// Reset treat counter to full
  void sendTreatCounterReset() {
    sendCommand('treat_counter_reset');
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

  /// Toggle blue mood LED on/off
  /// action: 'on', 'off', or 'toggle'
  void sendMoodLed(String action) {
    sendCommand('mood_led', {'action': action});
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

  /// Record video on the robot camera
  /// Robot records for [duration] seconds then sends video_ready with download_url.
  /// Use sendStopRecording() to stop early before duration expires.
  void sendRecordVideo({int duration = 15, String resolution = '1080p'}) {
    sendCommand('record_video', {
      'duration': duration,
      'resolution': resolution,
    });
  }

  /// Stop video recording early (before duration expires)
  void sendStopRecording() {
    sendCommand('stop_recording');
  }

  /// Call dog - plays attention/recall sound on robot
  void sendCallDog({String? dogId, String? dogName}) {
    print('WebSocket: sendCallDog dogId=$dogId, dogName=$dogName');
    sendCommand('call_dog', {
      if (dogId != null) 'dog_id': dogId,
      if (dogName != null) 'dog_name': dogName,
    });
  }

  /// Play a pre-recorded voice command on the robot
  void sendPlayVoice(String voiceType, {String? dogId}) {
    sendCommand('play_voice', {
      'voice_type': voiceType,
      if (dogId != null) 'dog_id': dogId,
    });
  }

  /// Upload a voice command recording to the robot
  void sendVoiceCommand(String commandId, String base64Data, {String format = 'wav', String dogId = 'default'}) {
    print('WebSocket: sendVoiceCommand name=$commandId, dogId=$dogId, format=$format, dataLen=${base64Data.length}');
    sendCommand('upload_voice', {
      'name': commandId,
      'dog_id': dogId,
      'data': base64Data,
      'format': format,
    });
  }

  /// Upload a song/audio file to the robot
  void sendUploadSong(String filename, String base64Data, String format) {
    print('WebSocket: sendUploadSong filename=$filename, format=$format, dataLen=${base64Data.length}');
    sendCommand('upload_song', {
      'filename': filename,
      'data': base64Data,
      'format': format,
    });
  }

  /// Build 41: Delete a song from the robot playlist
  void sendDeleteSong(String filename, {String? dogId}) {
    print('WebSocket: sendDeleteSong filename=$filename, dogId=$dogId');
    sendCommand('delete_song', {
      'filename': filename,
      if (dogId != null) 'dog_id': dogId,
    });
  }

  /// Send audio message to robot (push-to-talk)
  void sendAudioMessage(String base64Data, String format, int durationMs) {
    print('WebSocket: sendAudioMessage format=$format, duration=${durationMs}ms, dataLen=${base64Data.length}');
    sendCommand('ptt_play', {
      'data': base64Data,
      'format': format,
      'duration_ms': durationMs,
    });
  }

  /// Request audio from robot (listen)
  void requestAudioFromRobot(int durationSeconds) {
    print('WebSocket: requestAudioFromRobot duration=${durationSeconds}s');
    sendCommand('audio_request', {'duration': durationSeconds});
  }

  /// Request WebRTC video stream
  void requestVideoStream() {
    send({
      'type': 'webrtc_request',
      if (_sessionId != null) 'session_id': _sessionId,
    });
  }

  /// Send WebRTC answer
  void sendWebrtcAnswer(Map<String, dynamic> answer) {
    send({
      'type': 'webrtc_answer',
      if (_sessionId != null) 'session_id': _sessionId,
      ...answer,
    });
  }

  /// Send WebRTC ICE candidate
  void sendWebrtcIce(Map<String, dynamic> candidate) {
    send({
      'type': 'webrtc_ice',
      if (_sessionId != null) 'session_id': _sessionId,
      ...candidate,
    });
  }

  /// B4: best-effort graceful close. Tells relay we're shutting down so it can
  /// notify the robot to tear down its PeerConnection immediately, without
  /// waiting for the heartbeat timeout.
  void sendClientClosing() {
    if (_sessionId == null) return;
    send({
      'type': 'client_closing',
      'session_id': _sessionId,
    });
  }

  // ============ Schedule Commands (Build 38) ============
  // Schedules are stored on robot for offline execution.
  // All schedule operations go via WebSocket, not REST.

  /// Request schedules from robot
  void sendGetSchedules() {
    print('WebSocket: sendGetSchedules');
    sendCommand('get_schedules', {});
  }

  /// Create a new schedule on robot
  void sendCreateSchedule({
    required String scheduleId,
    required String missionName,
    required String dogId,
    required String type,
    required String startTime,
    List<String> daysOfWeek = const [],
    bool enabled = true,
    int cooldownHours = 24,
  }) {
    print('WebSocket: sendCreateSchedule id=$scheduleId, mission=$missionName');
    sendCommand('create_schedule', {
      'schedule_id': scheduleId,
      'mission_name': missionName,
      'dog_id': dogId,
      'type': type,
      'start_time': startTime,
      'days_of_week': daysOfWeek,
      'enabled': enabled,
      'cooldown_hours': cooldownHours,
    });
  }

  /// Update an existing schedule on robot
  void sendUpdateSchedule({
    required String scheduleId,
    String? missionName,
    String? dogId,
    String? type,
    String? startTime,
    List<String>? daysOfWeek,
    bool? enabled,
    int? cooldownHours,
  }) {
    print('WebSocket: sendUpdateSchedule id=$scheduleId');
    sendCommand('update_schedule', {
      'schedule_id': scheduleId,
      if (missionName != null) 'mission_name': missionName,
      if (dogId != null) 'dog_id': dogId,
      if (type != null) 'type': type,
      if (startTime != null) 'start_time': startTime,
      if (daysOfWeek != null) 'days_of_week': daysOfWeek,
      if (enabled != null) 'enabled': enabled,
      if (cooldownHours != null) 'cooldown_hours': cooldownHours,
    });
  }

  /// Delete a schedule from robot
  void sendDeleteSchedule(String scheduleId) {
    print('WebSocket: sendDeleteSchedule id=$scheduleId');
    sendCommand('delete_schedule', {'schedule_id': scheduleId});
  }

  /// Enable/disable global scheduling on robot
  void sendSetSchedulingEnabled(bool enabled) {
    print('WebSocket: sendSetSchedulingEnabled enabled=$enabled');
    sendCommand('set_scheduling_enabled', {'enabled': enabled});
  }

  // ============ Coach Commands (Build 38) ============

  /// Force a specific trick in coach mode
  void sendForceTrick(String trick) {
    print('WebSocket: sendForceTrick trick=$trick');
    sendCommand('force_trick', {'trick': trick});
  }

  /// Enable/disable camera tracking
  void sendSetTrackingEnabled(bool enabled) {
    print('WebSocket: sendSetTrackingEnabled enabled=$enabled');
    sendCommand('set_tracking_enabled', {'enabled': enabled});
  }

  // ============ Mission Commands (Build 38) ============

  /// Request current mission status from robot
  void sendGetMissionStatus() {
    print('WebSocket: sendGetMissionStatus');
    sendCommand('get_mission_status', {});
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();

    // Close with timeout — if connection is already dead, don't hang
    if (_channel != null) {
      try {
        await _channel!.sink.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('WebSocket: sink.close() timed out — connection already dead');
          },
        );
      } catch (e) {
        print('WebSocket: Error during disconnect: $e');
      }
    }
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
    _videoController.close();
    _rateLimitController.close();
  }
}
