import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../session/session_id.dart';
import '../utils/conn_trace.dart';
import '../utils/remote_logger.dart';

/// WebSocket connection state
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Fix #2: retry policy for a WS close, derived from the relay close code.
enum WsCloseReason {
  /// Clean, app-initiated close (1000) — do not reconnect.
  cleanClose,

  /// Transient failure (4002 heartbeat, 1006/1005/network) — reconnect
  /// with exponential backoff.
  retryable,

  /// Relay rejected the handshake (4000) — permanent; a bug, not transient.
  malformedHandshake,

  /// Invalid / expired token (4001) — permanent; user must re-authenticate.
  invalidToken,

  /// Another app instance took over (4003) — expected; not an error.
  superseded,
}

/// WebSocket event from the robot
class WsEvent {
  final String type;
  final Map<String, dynamic> data;

  /// Relay replay-buffer sequence number — per-device, monotonic. Tagged on
  /// every feed-worthy event (live and buffered) by the relay's store-and-
  /// forward buffer. Null on messages the relay doesn't sequence (local mode,
  /// WebRTC signaling, acks).
  final int? seq;

  /// True when this event was replayed from the relay's per-device buffer on
  /// (re)connect rather than delivered live. Used to timestamp the feed entry
  /// with [tsServer] (its real time) instead of arrival time, and available
  /// for callers that want to avoid re-alerting on a backlog.
  final bool buffered;

  /// Authoritative server timestamp (ISO8601) the relay assigns on ingest.
  /// Preferred over device/robot clocks for feed ordering. Null in local mode.
  final String? tsServer;

  /// Stable relay event id (top-level). Used to dedup the feed across the two
  /// hydration sources (REST `/api/activity` history + WS replay buffer) — the
  /// relay must assign the SAME id to an event in both. Null for live robot
  /// events that don't carry one (the feed then falls back to an ephemeral id).
  final String? id;

  WsEvent({
    required this.type,
    required this.data,
    this.seq,
    this.buffered = false,
    this.tsServer,
    this.id,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    // Use 'type' as primary, fall back to 'event' for backward compatibility
    final messageType = json['type'] as String? ?? json['event'] as String?;

    // Data can be nested in 'data' field OR at top level
    // Robot sends: {"type": "battery", "level": 95, "charging": true}
    // Or relay sends: {"type": "battery", "data": {"level": 95, "charging": true}}
    //
    // Build 131: EVERY field is parsed defensively. Previously strict casts
    // (`as String?`, `as int?`, `as Map<String,dynamic>`) threw a TypeError when
    // the relay sent a field with an unexpected runtime type (e.g. a numeric
    // `ts_server`/`seq`), and _onMessage's try/catch swallowed it with print()
    // — invisible in conn_trace. That silently dropped controller_status (the
    // "delivered but never rendered" bug) and is a landmine for any event.
    Map<String, dynamic> eventData;
    final dataField = json['data'];
    if (dataField is Map) {
      eventData = Map<String, dynamic>.from(dataField);
    } else {
      // Use entire message as data (excluding type/event fields)
      eventData = Map<String, dynamic>.from(json)
        ..remove('type')
        ..remove('event');
    }

    return WsEvent(
      type: messageType ?? 'unknown',
      data: eventData,
      // Store-and-forward envelope fields live at the TOP level, siblings of
      // type/device_id — they'd be discarded by the nested-data branch above.
      seq: _asInt(json['seq']),
      buffered: json['buffered'] == true,
      tsServer: json['ts_server']?.toString(),
      // Relay emits the stable dedup id as top-level `id` on replay frames but
      // as `event_id` on live-forwarded messages — accept either so live and
      // REST-hydrated copies of the same event share an id and dedup.
      id: json['id']?.toString() ?? json['event_id']?.toString(),
    );
  }

  /// Lenient int parse: accepts int, num (e.g. 8548.0), or numeric string.
  /// Never throws — returns null for anything unparseable.
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
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

  /// Device id the current relay session was BOUND to via session_hello.
  /// The relay routes robot events by this binding, not by later commands'
  /// device_id — callers use this to detect a stale binding after the real
  /// device selection loads (cold start binds the default before prefs/
  /// device-list resolve).
  String? get sessionDeviceId => _sessionDeviceId;
  // Fix #1: relay handshake gate. The relay 4000-closes the socket unless
  // session_hello is the FIRST frame, and only confirms the connection by
  // replying with a session_ack frame. Until that ack arrives, every
  // outbound frame except session_hello is held in _pendingFrames.
  //
  // _expectRelayHandshake is false only for local mode (direct ws:// to the
  // robot — no relay, no handshake). _sessionId itself is never null:
  // connect() always sets it to SessionId.current.
  bool _expectRelayHandshake = true;
  bool _handshakeComplete = false;
  final List<Map<String, dynamic>> _pendingFrames = [];
  Timer? _handshakeTimeoutTimer;
  static const Duration _handshakeTimeout = Duration(seconds: 10);
  static const int _maxPendingLossyFrames = 50;
  // WebRTC signaling frames must never be dropped from the pre-handshake
  // queue — losing one breaks negotiation. Everything else is lossy.
  static const Set<String> _losslessFrameTypes = {
    'webrtc_request',
    'webrtc_answer',
    'webrtc_ice',
  };
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // ===== Store-and-forward: relay replay-buffer watermark =====
  // Per-device monotonic seq of the last feed event we've durably accepted.
  // Sent in session_hello (last_seen_seq) so the relay replays everything
  // newer on (re)connect; advanced as buffered + live events arrive; persisted
  // so it survives app restart. The relay keeps the seq counter persistent per
  // device (contract item (a)), so this watermark stays comparable across
  // sessions AND relay restarts — no epoch/reset handshake needed.
  int _lastSeenSeq = 0;
  String? _watermarkDeviceId;
  Timer? _watermarkPersistTimer;
  static const String _watermarkPrefix = 'ws_seq_watermark_';

  // Build 140: dedup keys for filtered-event traces (target-device drops and
  // live watermark drops) — first occurrence per key per socket is traced,
  // the rest stay quiet so a stuck filter can't flood the 500-line ring
  // buffer. Cleared on each fresh socket in _doConnect.
  final Set<String> _tracedFilterDrops = <String>{};

  /// The current session id sent with the session_hello frame and tagged on
  /// every signaling frame. Null until [connect] is called.
  String? get sessionId => _sessionId;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  final _stateController = StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  final _eventController = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get eventStream => _eventController.stream;

  /// Build 130: direct delivery hook for `controller_*` events. The controller
  /// pairing provider sets this and receives events synchronously at parse time,
  /// bypassing the broadcast `eventStream` — a screen-scoped late subscriber to
  /// that broadcast stream was silently missing the probe reply (event added to
  /// the stream, ws-controller-rx logged, but the listener never fired). A
  /// direct callback at the proven-firing parse site is timing-independent.
  void Function(WsEvent event)? onControllerEvent;

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

  // Fix #2: close-reason stream — lets connection_provider distinguish a
  // permanent close (no retry; route to re-login / superseded) from a
  // retryable one (websocket_client handles the socket-level retry).
  final _closeReasonController = StreamController<WsCloseReason>.broadcast();

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
  Stream<WsCloseReason> get closeReasonStream => _closeReasonController.stream;

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
    bool expectRelayHandshake = true,
  }) async {
    // Build 101: short-circuit only if EVERY session-relevant param matches
    // what's already on the wire. A naked url-only check defeated multi-robot
    // device switching: _handleDeviceSwitch generated a fresh session_id and
    // passed the new device_id down, but this guard bailed before the new
    // session_hello could be sent, leaving the relay's routing bound to the
    // original device for the rest of the session. Logs across an entire
    // 7-minute window showed session_id pinned to 1a99e462… across five
    // device-switch attempts; only logout+login broke the binding.
    final nextSessionId = sessionId ?? SessionId.current;
    if (_state == WsConnectionState.connected &&
        _currentUrl == url &&
        _sessionId == nextSessionId &&
        _sessionUserId == userId &&
        _sessionDeviceId == deviceId) {
      connTrace('ws-connect-noop',
          'session=$nextSessionId device=$deviceId — params unchanged');
      return;
    }

    await disconnect();
    _currentUrl = url;
    _sessionId = nextSessionId;
    _sessionUserId = userId;
    _sessionDeviceId = deviceId;
    // Fix #1: local mode (local_connection_service) passes false — the
    // robot's local WS speaks no session_hello/session_ack handshake.
    _expectRelayHandshake = expectRelayHandshake;
    _reconnectAttempts = 0;

    // Store-and-forward: load this device's replay watermark before the first
    // session_hello so last_seen_seq is correct. Local mode has no relay
    // buffer — clear the watermark so stale relay seqs can't dedup local events.
    if (expectRelayHandshake && deviceId != null) {
      await _loadWatermark(deviceId);
    } else {
      _lastSeenSeq = 0;
      _watermarkDeviceId = null;
    }

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentUrl == null) return;

    _setState(WsConnectionState.connecting);
    // Fix #1: each new socket needs a fresh handshake before non-hello
    // frames may flow. Drop any frames queued against the previous socket.
    _handshakeComplete = false;
    _pendingFrames.clear();
    _handshakeTimeoutTimer?.cancel();
    _tracedFilterDrops.clear();

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
      connTrace('ws-relay-open', _currentUrl ?? '');

      // Listen for messages FIRST so the relay's session_ack is never missed.
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Fix #1: session_hello MUST be the first frame on the socket. The
      // handshake gate in send() holds every other outbound frame until the
      // relay replies with session_ack (see _onMessage / _openHandshakeGate).
      //
      // Build 90: session_hello RE-ENABLED. Diagnosed against the deployed
      // relay code (wimzrelay/app/routers/websocket.py): the handshake is
      // mandatory (4000 close on timeout) and validates `user_id` against
      // the JWT `sub` claim (which is `user_NNNNNN`, not the email — the
      // login response only returns `token`/`expires_in`, so we extract
      // `sub` from the JWT itself in connection_provider).
      _sendSessionHello();

      if (_expectRelayHandshake) {
        // Relay handshake in flight — arm a timeout. If session_ack never
        // arrives (e.g. the relay's _safe_send_json dropped it on a
        // half-broken socket) we close and retry rather than hang.
        _handshakeTimeoutTimer?.cancel();
        _handshakeTimeoutTimer = Timer(_handshakeTimeout, _onHandshakeTimeout);
      } else {
        // Local mode — no relay handshake, no session_ack will come.
        // Open the gate now so queued frames can flow.
        _openHandshakeGate();
      }

      // Flush pending remote logs — these queue behind session_hello while
      // the handshake gate is still closed.
      RemoteLogger.onConnected();

      // Start ping timer
      _startPingTimer();
    } catch (e) {
      print('WebSocket connection error: $e');
      connTrace('ws-connect-error', '$e');
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
    if (sourceId == _targetDeviceId) return true;
    // Build 140: received-but-filtered events were fully invisible (the relay
    // forwards ALL owned robots' events; dropping other robots' is by design,
    // but a target-id mismatch for the CONNECTED robot looks identical from
    // the outside — "delivered but never rendered"). Trace the first drop per
    // (type, source) per socket so diagnostics show what got filtered and why.
    final msgType = json['type'] as String? ?? json['event'] as String?;
    if (_tracedFilterDrops.add('target:$msgType:$sourceId')) {
      connTrace('ws-target-drop',
          'type=$msgType from=$sourceId target=$_targetDeviceId');
    }
    return false;
  }

  void _onMessage(dynamic message) {
    try {
      var json = jsonDecode(message as String) as Map<String, dynamic>;
      var msgType = json['type'] as String? ?? json['event'] as String?;

      // Per-message firehose — debug builds only. Gated so release logs don't
      // carry device/robot state (and to cut log spam). Build 110.
      if (kDebugMode) print('WS MSG [$msgType]: $json');

      // Fix #1: the relay confirms the handshake with a session_ack frame.
      // Until it arrives, every non-hello outbound frame is queued (send()).
      if (!_handshakeComplete && msgType == 'session_ack') {
        final ackSession = json['session_id'] as String?;
        if (ackSession != null && ackSession != _sessionId) {
          print('WS: ignoring session_ack for stale session '
              '$ackSession (ours=$_sessionId)');
        } else {
          print('WS: session_ack received — handshake complete');
          connTrace('ws-session-ack', _sessionId ?? '');
          _openHandshakeGate();
        }
      }

      // Store-and-forward: dedup + advance the replay watermark. The relay
      // tags every feed event (buffered replays AND live) with a per-device
      // monotonic `seq`. Drop anything at-or-below the watermark — this
      // collapses overlapping replays across reconnects — and advance on
      // anything newer. Messages without a seq (acks, signaling, local mode)
      // are untouched and fall through to normal routing below.
      //
      // Build 127: `controller_*` events are transient live state. The relay
      // assigns them a seq (shared monotonic counter) but does NOT add them to
      // the replay buffer. If we let them advance the persisted watermark, a
      // buffered feed event (bark/alert) sitting at a lower seq would be dropped
      // at the `seq <= _lastSeenSeq` guard on the next reconnect — silently
      // losing a notification. Exempt them so the watermark only tracks
      // replayable feed events.
      final seq = json['seq'];
      final isControllerMsg = msgType?.startsWith('controller_') ?? false;
      // Build 140: audio_state joins the controller_* carve-out. For a type
      // outside FEED_WORTHY_EVENTS the watermark gate can only do harm:
      // (a) a watermark sitting ahead of the robot's live counter silently
      // swallows EVERY frame — the "now-playing text renders for one robot
      // only" bug — and (b) letting it advance the persisted watermark skips
      // buffered feed events (barks/alerts) on the next reconnect, exactly
      // the Build 127 controller_* lesson. Any other type confirmed absent
      // from FEED_WORTHY_EVENTS belongs in this set too.
      //
      // Build 146 (relay confirmed 2026-07-27): coaching_started,
      // coach_progress, and local_mode_starting get a seq but never replay —
      // same carve-out. audio_state stays here even though the relay now
      // latches and replays its LATEST frame (buffered:true, one frame max,
      // 24h window, 2026-07-26): the replay is a deliberate reconnect seed,
      // not feed history, so it must not be watermark-dropped nor advance
      // the watermark.
      // treat_counter_ack (robot 8e8c91c): direct reply to treat_counter_set/
      // reset. Transient live state, never replayed — same carve-out logic as
      // audio_state. [[transient-event-watermark-gate]]
      //
      // update_status (OTA contract 2026-08-07): the contract EXPLICITLY
      // mandates this carve-out — progress frames are transient live state,
      // never replayed; letting them touch the watermark reproduces the
      // "renders on one robot only" bug.
      final isTransientMsg = isControllerMsg ||
          msgType == 'audio_state' ||
          msgType == 'coaching_started' ||
          msgType == 'coach_progress' ||
          msgType == 'local_mode_starting' ||
          msgType == 'treat_counter_ack' ||
          msgType == 'update_status';
      if (isControllerMsg) {
        // Build 129: prove on-device that controller_* reaches the socket and
        // survives the watermark gate (the pre-129 drop point). Read via
        // Settings → Connection Diagnostics. [[debug-via-in-app-diagnostics]]
        connTrace('ws-controller-rx', '$msgType seq=$seq wm=$_lastSeenSeq');
        // Build 130: deliver directly to the controller provider here, at the
        // site we've proven fires. The broadcast eventStream below still gets it
        // for any other listener, but the provider no longer depends on it.
        final cb = onControllerEvent;
        if (cb != null) {
          connTrace('ws-controller-cb', msgType ?? '');
          // try/catch + connTrace so a parse/handler failure is VISIBLE in the
          // diagnostics log instead of being swallowed by the outer print().
          try {
            cb(WsEvent.fromJson(json));
          } catch (e) {
            connTrace('ws-controller-err', '$e');
          }
        } else {
          connTrace('ws-controller-nocb', msgType ?? '');
        }
      }
      if (seq is int && !isTransientMsg) {
        if (seq <= _lastSeenSeq) {
          // Duplicate per the watermark. Expected for buffered replays
          // (overlapping replay windows across reconnects); a LIVE frame
          // landing here means the watermark is ahead of the relay's counter
          // and we are silently eating real events — trace it (once per type
          // per socket) so this class of bug shows in Connection Diagnostics.
          if (json['buffered'] != true &&
              _tracedFilterDrops.add('wm:$msgType')) {
            connTrace('ws-wm-drop-live',
                'type=$msgType seq=$seq wm=$_lastSeenSeq device=$_watermarkDeviceId');
          }
          return;
        }
        _lastSeenSeq = seq;
        _scheduleWatermarkPersist();
      }

      // Build 146: unwrap the robot's LOCAL event envelope. Over /ws/local the
      // robot wraps bus events as
      //   {"type":"event","category":"system|vision|audio|…",
      //    "data":{"subtype":"coaching_started", …} }   — or double-nested:
      //   "data":{"subtype":"audio_state","data":{…payload…}}
      // Before this, such frames fell through to the default branch as type
      // 'event', which NO handler matches — every local bus event
      // (coaching_started, coach_progress, detections, audio_state) was
      // delivered and then dropped on the floor. Rewrite to the flat shape the
      // relay uses (type = subtype) so the normal routing below applies.
      // Relay frames are untouched: they never carry `category`.
      final envCategory = json['category'];
      final envData = json['data'];
      if (msgType == 'event' && envCategory != null && envData is Map) {
        final subtype = envData['subtype']?.toString();
        if (subtype != null && subtype.isNotEmpty) {
          final inner = envData['data'];
          final flat = <String, dynamic>{
            ...Map<String, dynamic>.from(envData)
              ..remove('subtype')
              ..remove('data'),
            if (inner is Map) ...Map<String, dynamic>.from(inner),
            'subtype': subtype,
            'category': envCategory.toString(),
            if (json['timestamp'] != null) 'timestamp': json['timestamp'],
          };
          // Local reward events keep the relay's type name so the existing
          // `case 'reward'` + data.subtype consumers match.
          msgType = subtype == 'treat_dispensed' ? 'reward' : subtype;
          flat['type'] = msgType;
          json = flat;
          if (_tracedFilterDrops.add('unwrap:$subtype')) {
            connTrace('ws-local-unwrap', 'category=$envCategory subtype=$subtype');
          }
        }
      }

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
        // Robot 8e8c91c treat-counter events/acks (carry treats_given +
        // treat_capacity + treats_remaining). Listed explicitly so they get
        // the target-device filter instead of the unfiltered default case.
        case 'treats_low':
        case 'treats_loaded':
        case 'treats_empty':
        case 'treat_counter_ack':
        // OTA update progress (contract 2026-08-07) — target-device filtered
        case 'update_status':
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

        // Build 146: robot-authoritative state on (re)connect. /ws/local sends
        // `connected` (with current_mode) and `initial_status` (with
        // data.system_state + data.audio_status) automatically on every
        // connect — the app must sync FROM these instead of re-asserting its
        // own cached mode (the set_mode-stomping bug, robot journal
        // 2026-07-26). Forwarded for mode_provider + audio UI seeding.
        case 'connected':
        case 'initial_status':
          connTrace('ws-robot-state', '$msgType received');
          _eventController.add(WsEvent.fromJson(json));
          break;

        // Build 146: network_state — robot's WiFi/AP breadcrumb, sent on every
        // relay connect and after every WiFi rejoin. Carries local_ap
        // credentials for the offline "join the robot's hotspot" prompt.
        // Deliberately NOT filtered by _isFromTargetDevice: the latest
        // breadcrumb per robot is worth caching even for a robot the app isn't
        // currently targeting.
        case 'network_state':
        case 'local_mode_starting':
          connTrace('ws-network-state', '$msgType device=${json['device_id']}');
          _eventController.add(WsEvent.fromJson(json));
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
          final barkTsServer = json['ts_server'] as String?;
          final barkBuffered = json['buffered'] == true;
          final barkEvent = WsEvent(
            type: 'event',
            seq: json['seq'] as int?,
            buffered: barkBuffered,
            tsServer: barkTsServer,
            // Replay frames carry `id`; live ones carry `event_id` — take either.
            id: json['id'] as String? ?? json['event_id'] as String?,
            data: {
              ...json, // Spread robot data first
              // Our overrides AFTER spread so they take precedence:
              'event_type': 'barking',
              // Buffered (replayed) barks keep their real server time so they
              // land at the right point in the feed, not bunched at "now".
              // Live barks fall back to device time when the relay supplied no
              // ts_server (local mode).
              'timestamp': barkTsServer ?? DateTime.now().toIso8601String(),
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
          break;
        case 'ack':
        case 'command_ack':
        case 'command_response':
        case 'response':
          // A-LED: acks used to be swallowed here, so the app could never
          // tell a delivered command from one that died in transit — every
          // "LED didn't fire" report was undiagnosable. Forward them so
          // delivery can be verified (diagnostics LED ping times these).
          _eventController.add(WsEvent.fromJson(json));
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
    // Fix #1: a close before session_ack means the relay never confirmed
    // this session — drop the queued frames. They are tied to this
    // session_id and must not be replayed on the next connection;
    // webrtc_provider resubmits webrtc_request on reconnect if needed.
    _handshakeTimeoutTimer?.cancel();
    // Fix #3: stop the heartbeat the instant the socket closes — the next
    // _doConnect starts a fresh timer; the old one must not linger and tick
    // against a dead socket.
    _pingTimer?.cancel();
    if (!_handshakeComplete && _pendingFrames.isNotEmpty) {
      print('WebSocket: dropping ${_pendingFrames.length} pre-handshake '
          'frame(s) — session not confirmed');
      _pendingFrames.clear();
    }
    if (_state == WsConnectionState.disconnected) return;

    // Fix #2: retry only on retryable close codes. Permanent codes
    // (4000/4001/4003/1000) must not be retried — retrying them is what
    // produced the reconnect storm.
    final wsCloseReason = _classifyClose(code);
    print('WebSocket: close classified as $wsCloseReason');
    _closeReasonController.add(wsCloseReason);

    if (wsCloseReason == WsCloseReason.retryable) {
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    } else {
      // Permanent close — no reconnect. malformedHandshake / invalidToken
      // are errors; superseded / cleanClose are quiet stops.
      final isError = wsCloseReason == WsCloseReason.malformedHandshake ||
          wsCloseReason == WsCloseReason.invalidToken;
      _setState(isError
          ? WsConnectionState.error
          : WsConnectionState.disconnected);
    }
  }

  /// Fix #2: map a WS close code to a retry policy per the relay contract.
  /// 4000/4001/4003/1000 are permanent; everything else is retryable.
  static WsCloseReason _classifyClose(int? code) {
    switch (code) {
      case 4000: // relay rejected the handshake — a bug, not transient
        return WsCloseReason.malformedHandshake;
      case 4001: // invalid / expired token — user must re-authenticate
        return WsCloseReason.invalidToken;
      case 4003: // another app instance took over — expected, not an error
        return WsCloseReason.superseded;
      case 1000: // clean close, app-initiated
        return WsCloseReason.cleanClose;
      case 4002: // heartbeat timeout — transient
      default: // 1006 / 1005 / null / network errors — transient
        return WsCloseReason.retryable;
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

    // Fix #2: exponential backoff — 1s, 2s, 4s, 8s, 16s — capped at 30s.
    final delayMs =
        (1000 * (1 << (_reconnectAttempts - 1))).clamp(1000, 30000);
    final delay = Duration(milliseconds: delayMs);

    print('Reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _doConnect);
  }

  /// Fix #3: heartbeat. Cancels any prior timer first — a reconnect runs
  /// _doConnect → _startPingTimer, so exactly one ping timer is ever live
  /// and it always belongs to the current socket. Cadence is 10s
  /// (AppConstants.websocketPingInterval); the relay 4002-closes after
  /// ~25s without a ping, so 10s gives 2-3 pings of margin for blips.
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.websocketPingInterval, (_) {
      // Fix #3: only fire once the socket is open AND the handshake is
      // complete — never ping a closed or pre-session_ack socket (the
      // same root-cause family as the original debug_log-before-hello bug).
      if (_state != WsConnectionState.connected || !_handshakeComplete) {
        return;
      }
      send({'type': 'ping'});
      // Fix #3: log every heartbeat so cadence is verifiable in the
      // Connection Diagnostics trace.
      connTrace('ws-heartbeat', 'ping sent');
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
    // Fix #1: session_hello is the relay handshake frame. Local-mode
    // connections (direct ws:// to the robot) have no relay and no
    // handshake. _sessionId is never null here — connect() always sets it
    // to SessionId.current — so the only skip condition is local mode.
    if (!_expectRelayHandshake) return;
    send({
      'type': 'session_hello',
      'session_id': _sessionId,
      if (_sessionUserId != null) 'user_id': _sessionUserId,
      if (_sessionDeviceId != null) 'device_id': _sessionDeviceId,
      // Store-and-forward: relay replays every buffered event with seq >
      // last_seen_seq for this device, oldest→newest, before resuming live.
      'last_seen_seq': _lastSeenSeq,
    });
  }

  /// Send a message to the server.
  ///
  /// Fix #1: until the relay confirms the handshake with session_ack, every
  /// frame except session_hello is held in [_pendingFrames]. Sending ahead
  /// of session_hello makes the relay 4000-close the socket.
  void send(Map<String, dynamic> data) {
    if (_state != WsConnectionState.connected) {
      print('Cannot send: WebSocket not connected');
      return;
    }

    if (!_handshakeComplete && data['type'] != 'session_hello') {
      final type = data['type'] as String? ?? '';
      if (_losslessFrameTypes.contains(type)) {
        // WebRTC signaling — never dropped; losing one breaks negotiation.
        _pendingFrames.add(data);
        print('WS QUEUED (pre-handshake, lossless): $type');
      } else if (_pendingFrames.length < _maxPendingLossyFrames) {
        _pendingFrames.add(data);
        print('WS QUEUED (pre-handshake): $type');
      } else {
        print('WS DROPPED (pre-handshake queue full): $type');
      }
      return;
    }

    _writeFrame(data);
  }

  /// Write a frame straight to the socket, bypassing the handshake gate.
  void _writeFrame(Map<String, dynamic> data) {
    try {
      final json = jsonEncode(data);
      if (kDebugMode) print('WS SEND: $json'); // debug-only firehose — Build 110
      _channel?.sink.add(json);
    } catch (e) {
      print('WebSocket send error: $e');
    }
  }

  /// Fix #1: open the handshake gate and flush queued frames in order.
  /// Called when the relay replies with session_ack, or immediately when no
  /// relay handshake applies (local mode / session_hello suppressed).
  void _openHandshakeGate() {
    if (_handshakeComplete) return;
    _handshakeComplete = true;
    _handshakeTimeoutTimer?.cancel();
    _handshakeTimeoutTimer = null;
    if (_pendingFrames.isEmpty) return;
    print('WS: flushing ${_pendingFrames.length} queued frame(s) post-handshake');
    final queued = List<Map<String, dynamic>>.from(_pendingFrames);
    _pendingFrames.clear();
    for (final frame in queued) {
      _writeFrame(frame);
    }
  }

  /// Fix #1: session_ack did not arrive in time. The relay may have dropped
  /// it on a half-broken socket — treat as handshake failure: drop the
  /// queued frames (they belong to a session the relay never confirmed) and
  /// close the socket so _onDone schedules a reconnect.
  void _onHandshakeTimeout() {
    if (_handshakeComplete) return;
    print('WebSocket: session_ack not received within '
        '${_handshakeTimeout.inSeconds}s — handshake failed, closing');
    connTrace('ws-handshake-timeout', '');
    _pendingFrames.clear();
    _channel?.sink.close();
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
  /// Format: {"type":"command","command":"dispense_treat","data":{"dog_id":...}}
  /// Build 140 attribution: [dogId]/[dogName] name the dog the owner is
  /// treating (the app's selected dog — the human tapping Give Treat knows
  /// who it's for, no vision needed). The robot echoes them onto the emitted
  /// treat/reward event and relay row so per-dog stats count manual treats.
  /// Contract: .claude/EVENT_DOG_ATTRIBUTION_CONTRACT_2026-07-13.md
  void sendTreatCommand({String? dogId, String? dogName}) {
    sendCommand('dispense_treat', {
      if (dogId != null) 'dog_id': dogId,
      if (dogName != null) 'dog_name': dogName,
    });
  }

  /// OTA contract 2026-08-07: ask the robot to update itself to [version].
  /// Robot streams `update_status` events back; it refuses (with reason)
  /// unless idle, battery >= 30%, and no active WebRTC session.
  void sendStartUpdate(String version) {
    sendCommand('start_update', {'version': version});
  }

  /// Rotate treat carousel
  void sendCarouselRotate() {
    sendCommand('carousel_rotate');
  }

  /// Set treat counter after a load: [count] = treats loaded (zeroes
  /// treats_given robot-side), optional [capacity] when the carousel size
  /// differs from the amount loaded. Robot replies with treat_counter_ack
  /// carrying the authoritative counter fields.
  void sendTreatCounterSet(int count, {int? capacity}) {
    sendCommand('treat_counter_set', {
      'count': count,
      if (capacity != null) 'capacity': capacity,
    });
  }

  /// Zero treats_given, keeping capacity. Robot replies with treat_counter_ack
  /// carrying REAL values — do not assume zero remaining from a reset.
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

  /// Set system audio volume (0-100) on the robot's VolumeManager.
  /// Per the volume contract the relay command's canonical key is `volume`
  /// (`level` is an accepted alias) and the local /ws command uses `level` —
  /// so both keys are sent, making the frame valid on every path.
  void sendAudioVolume(int level) {
    sendCommand('audio_volume', {'volume': level, 'level': level});
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

  // Build 89: session_id tagging on signaling frames disabled along with
  // session_hello. The relay was rejecting the augmented payloads in some
  // configurations. Restored to the Build 85 bare format.
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

  /// Force a specific trick in coach mode.
  ///
  /// Build 106: now carries `dog_id`/`dog_name` so the robot's TTS substitutes
  /// the real name into the prompt instead of falling back to "Dog". Robot
  /// should treat both as optional — the app refuses to send a force_trick
  /// without at least one of them — but if a future caller does send neither,
  /// robot can still fall back to its previous behaviour.
  /// `replace: true` hard-cancels any running trick session robot-side (FSM
  /// reset, cooldowns cleared, visible dogs fast-tracked) and starts [trick]
  /// within a beat; without it the trick is staged for the next session
  /// (robot contract fbc5d10, 2026-07-26). Robot answers with
  /// `replaced: true/false` reporting whether anything was actually cancelled.
  void sendForceTrick(String trick,
      {String? dogId, String? dogName, bool replace = false}) {
    print('WebSocket: sendForceTrick trick=$trick dog=$dogName ($dogId) '
        'replace=$replace');
    final data = <String, dynamic>{'trick': trick};
    if (dogId != null) data['dog_id'] = dogId;
    if (dogName != null) data['dog_name'] = dogName;
    if (replace) data['replace'] = true;
    sendCommand('force_trick', data);
  }

  /// Enable/disable camera tracking
  void sendSetTrackingEnabled(bool enabled) {
    print('WebSocket: sendSetTrackingEnabled enabled=$enabled');
    sendCommand('set_tracking_enabled', {'enabled': enabled});
  }

  /// Set the robot's video-quality mode.
  /// 'auto' releases the robot's adaptive bitrate controller; 'low'/'medium'/
  /// 'high' pin the tier and disable adaptation until set back to 'auto'.
  /// Sent as a bare typed frame on the relay command channel (not the
  /// WebRTC data channel) per the adaptive-bitrate contract.
  void sendVideoQualityMode(String mode) {
    print('WebSocket: sendVideoQualityMode mode=$mode');
    send({'type': 'set_video_quality', 'mode': mode});
  }

  /// Set the robot's day/night camera override.
  /// `override` is one of 'auto' | 'force_day' | 'force_night'. Per the robot
  /// contract (nightvision.md / relay_client._handle_command) this rides the
  /// standard relay-command envelope — same wrapper as set_mode and mood_led.
  /// The robot persists the choice and publishes the next night_mode_state
  /// heartbeat with it reflected.
  void sendNightModeOverride(String override) {
    print('WebSocket: sendNightModeOverride override=$override');
    sendCommand('set_night_mode_override', {'override': override});
  }

  /// Update Silent Guardian runtime config on the robot.
  /// Only fields supplied are mutated; null fields are omitted from the payload.
  /// `fastEscalationBpm`: 0 disables the fast-escalation jump; 10–90 BPM sets
  /// the sustained-bark threshold above which the robot bypasses the L1→L4
  /// ladder and goes straight to calming music.
  /// Robot mutates in memory only — app is source of truth; re-send on
  /// reconnect (see SilentGuardianNotifier).
  void sendSgConfig({int? fastEscalationBpm}) {
    final data = <String, dynamic>{};
    if (fastEscalationBpm != null) {
      data['fast_escalation_bpm'] = fastEscalationBpm;
    }
    if (data.isEmpty) return;
    print('WebSocket: sendSgConfig $data');
    sendCommand('sg_config', data);
  }

  // ============ Mission Commands (Build 38) ============

  /// Request current mission status from robot
  void sendGetMissionStatus() {
    print('WebSocket: sendGetMissionStatus');
    sendCommand('get_mission_status', {});
  }

  // ===== Store-and-forward watermark persistence =====

  /// Load the persisted replay watermark for [deviceId] into memory. Keyed by
  /// device so multi-robot users keep an independent catch-up point per robot.
  Future<void> _loadWatermark(String deviceId) async {
    if (_watermarkDeviceId == deviceId) return; // already in memory
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSeenSeq = prefs.getInt('$_watermarkPrefix$deviceId') ?? 0;
    } catch (e) {
      _lastSeenSeq = 0;
    }
    _watermarkDeviceId = deviceId;
  }

  /// Debounce watermark writes — a replay burst advances seq many times in a
  /// few ms; persist at most once a second (and on disconnect).
  void _scheduleWatermarkPersist() {
    _watermarkPersistTimer?.cancel();
    _watermarkPersistTimer =
        Timer(const Duration(seconds: 1), _persistWatermark);
  }

  Future<void> _persistWatermark() async {
    final device = _watermarkDeviceId;
    if (device == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_watermarkPrefix$device', _lastSeenSeq);
    } catch (_) {
      // Best-effort: the relay buffer still holds the events for next time.
    }
  }

  // ===== Test hooks (Build 140) =====
  // The routing/gating logic lives in private _onMessage on a singleton, so
  // the watermark + target-device regression tests need these narrow seams.

  /// Feed a raw inbound frame through the normal message-routing path.
  @visibleForTesting
  void debugHandleMessage(String raw) => _onMessage(raw);

  /// Force the in-memory replay watermark, bypassing the prefs load.
  @visibleForTesting
  void debugSetWatermark(int seq, {String? deviceId}) {
    _lastSeenSeq = seq;
    _watermarkDeviceId = deviceId;
  }

  @visibleForTesting
  int get debugWatermark => _lastSeenSeq;

  /// Reset the singleton's routing state between tests.
  @visibleForTesting
  void debugResetForTest() {
    _watermarkPersistTimer?.cancel();
    _watermarkPersistTimer = null;
    _lastSeenSeq = 0;
    _watermarkDeviceId = null;
    _targetDeviceId = null;
    _tracedFilterDrops.clear();
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _handshakeTimeoutTimer?.cancel();
    // Store-and-forward: flush the watermark before tearing down so an advance
    // from the last replay burst isn't lost if the debounce hadn't fired.
    _watermarkPersistTimer?.cancel();
    unawaited(_persistWatermark());
    _subscription?.cancel();
    _handshakeComplete = false;
    _pendingFrames.clear();

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
    _watermarkPersistTimer?.cancel();
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
    _closeReasonController.close();
  }
}
