import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'connection_provider.dart';
import 'device_provider.dart';
import 'video_quality_provider.dart';

/// WebRTC connection state
enum WebRTCState { disconnected, connecting, connected, error }

/// WebRTC state with renderer
class WebRTCConnectionState {
  final WebRTCState state;
  final RTCVideoRenderer? renderer;
  final String? sessionId;
  final String? errorMessage;
  final bool isAudioMuted;
  final bool isAutoListening;
  const WebRTCConnectionState({
    this.state = WebRTCState.disconnected,
    this.renderer,
    this.sessionId,
    this.errorMessage,
    this.isAudioMuted = true, // Default muted on first use per contract
    this.isAutoListening = false,
  });

  WebRTCConnectionState copyWith({
    WebRTCState? state,
    RTCVideoRenderer? renderer,
    String? sessionId,
    String? errorMessage,
    bool? isAudioMuted,
    bool? isAutoListening,
  }) {
    return WebRTCConnectionState(
      state: state ?? this.state,
      renderer: renderer ?? this.renderer,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isAutoListening: isAutoListening ?? this.isAutoListening,
    );
  }

  bool get isConnected => state == WebRTCState.connected;
}

/// Provider for WebRTC connection state and service
final webrtcProvider =
    StateNotifierProvider<WebRTCNotifier, WebRTCConnectionState>((ref) {
  return WebRTCNotifier(ref);
});

/// Convenience provider for just the state enum
final webrtcStateProvider = Provider<WebRTCState>((ref) {
  return ref.watch(webrtcProvider).state;
});

/// Provider for audio mute state (for UI binding)
final webrtcAudioMutedProvider = Provider<bool>((ref) {
  return ref.watch(webrtcProvider).isAudioMuted;
});

/// Provider for auto-listen state (for UI binding)
final webrtcAutoListeningProvider = Provider<bool>((ref) {
  return ref.watch(webrtcProvider).isAutoListening;
});

/// WebRTC state notifier - manages peer connection and video rendering
class WebRTCNotifier extends StateNotifier<WebRTCConnectionState> {
  final Ref _ref;
  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _renderer;
  RTCDataChannel? _dataChannel;
  MediaStream? _audioStream; // Remote audio stream from robot
  final List<StreamSubscription> _subscriptions = [];
  bool _rendererInitialized = false;
  bool _dataChannelOpen = false;
  String? _lastDeviceId;  // Store for auto-reconnect
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isPaused = false;  // True when app is backgrounded
  bool _isVideoOnlyPause = false;  // True when only video is paused (background audio)
  bool _isRequesting = false;  // Guard against concurrent requestVideoStream calls
  Timer? _autoListenTimer;  // Auto-listen after PTT send
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const String _mutePrefsKey = 'webrtc_audio_muted';

  /// Whether the data channel is ready for sending
  bool get isDataChannelOpen => _dataChannelOpen;

  /// Whether WebRTC is paused (app backgrounded)
  bool get isPaused => _isPaused;

  WebRTCNotifier(this._ref) : super(const WebRTCConnectionState()) {
    _loadMutePreference();
    _setupWebSocketListeners();
    _setupDeviceIdListener();
  }

  /// Load saved mute preference from SharedPreferences
  Future<void> _loadMutePreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true (muted) if not set — per v1.3 contract
    final isMuted = prefs.getBool(_mutePrefsKey) ?? true;
    state = state.copyWith(isAudioMuted: isMuted);
  }

  /// Toggle audio mute state (purely app-side, no command to robot)
  Future<void> toggleAudioMute() async {
    // User manual toggle overrides auto-listen
    if (_autoListenTimer?.isActive ?? false) {
      _autoListenTimer!.cancel();
      _autoListenTimer = null;
      state = state.copyWith(isAutoListening: false);
      print('WebRTC: Auto-listen cancelled by manual toggle');
    }

    final newMuted = !state.isAudioMuted;
    state = state.copyWith(isAudioMuted: newMuted);

    // Apply to audio track immediately
    _applyAudioMuteState(newMuted);

    // Persist preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutePrefsKey, newMuted);
    print('WebRTC: Audio ${newMuted ? "muted" : "unmuted"} (persisted)');
  }

  /// Temporarily force-unmute audio for [duration] after PTT send,
  /// then restore the user's persisted mute preference.
  void startAutoListen(Duration duration) {
    _autoListenTimer?.cancel();

    // Force-unmute audio tracks
    _applyAudioMuteState(false);
    state = state.copyWith(isAutoListening: true);
    print('WebRTC: Auto-listen started for ${duration.inSeconds}s');

    _autoListenTimer = Timer(duration, () {
      // Restore to persisted mute state
      _applyAudioMuteState(state.isAudioMuted);
      state = state.copyWith(isAutoListening: false);
      _autoListenTimer = null;
      print('WebRTC: Auto-listen ended, restored mute=${state.isAudioMuted}');
    });
  }

  /// Cancel auto-listen and restore persisted mute state.
  void cancelAutoListen() {
    if (_autoListenTimer?.isActive ?? false) {
      _autoListenTimer!.cancel();
      _autoListenTimer = null;
      _applyAudioMuteState(state.isAudioMuted);
      state = state.copyWith(isAutoListening: false);
      print('WebRTC: Auto-listen cancelled');
    }
  }

  /// Temporarily enable/disable audio track without persisting preference.
  /// Used by PTT to avoid iOS audio session conflict during recording.
  void setAudioTrackEnabled(bool enabled) {
    _applyAudioMuteState(!enabled);
  }

  /// Apply mute state to the remote audio track
  void _applyAudioMuteState(bool muted) {
    if (_audioStream != null) {
      for (final track in _audioStream!.getAudioTracks()) {
        track.enabled = !muted;
        print('WebRTC: Audio track enabled=${!muted}');
      }
    }
  }

  /// Listen for device ID changes and switch video stream accordingly
  void _setupDeviceIdListener() {
    _ref.listen<String>(deviceIdProvider, (previous, current) {
      if (previous != null && previous != current) {
        print('WebRTC: Device changed from $previous to $current');
        _handleDeviceSwitch(current);
      }
    });
  }

  /// Handle device switch.
  ///
  /// Build 99: switching robots mid-session requires a full WS reconnect —
  /// not just a WebRTC close + re-request. The relay binds each WS session
  /// to the device_id carried in `session_hello`, and that binding is set
  /// ONCE at WS connect time. Calling `setTargetDevice` only updates the
  /// app's local inbound filter; the relay still routes commands through
  /// the original device_id. That's why every command (including a fresh
  /// `webrtc_request`) effectively gets routed to the wrong robot — and
  /// why logout→login was the only previous workaround (it forced a brand-
  /// new WS with new session_hello).
  ///
  /// Fix: tear down WebRTC, then `connectionProvider.reconnect()` — which
  /// closes/reopens the WS and re-sends session_hello with the now-current
  /// deviceIdProvider value. The deviceStatusStream listener will fire
  /// `requestVideoStream(_lastDeviceId!)` automatically when the new robot
  /// reports online over the freshly-bound session.
  Future<void> _handleDeviceSwitch(String newDeviceId) async {
    final oldDeviceId = _lastDeviceId;

    // No active connection — just record the new id and exit.
    if (oldDeviceId == null && state.state == WebRTCState.disconnected) {
      print('WebRTC: No active connection, just updating device ID');
      _lastDeviceId = newDeviceId;
      connTrace('device-switch-noop',
          'old=null new=$newDeviceId — no active WebRTC, deferred');
      return;
    }

    print('WebRTC: ⚠️ SWITCHING VIDEO from $oldDeviceId to $newDeviceId');
    connTrace('device-switch-begin', 'old=$oldDeviceId new=$newDeviceId');

    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    // Clear renderer immediately so the old robot's last frame isn't shown
    // during the swap.
    if (_renderer != null) {
      print('WebRTC: Clearing renderer srcObject before switch');
      _renderer!.srcObject = null;
    }

    await _closeInternal();

    // Set the new target BEFORE the WS reconnect so the deviceStatusStream
    // listener auto-fires requestVideoStream(_lastDeviceId!) for the right
    // device when the relay's first device_status comes back.
    _lastDeviceId = newDeviceId;

    print('WebRTC: triggering WS reconnect so relay rebinds to $newDeviceId');
    final ok = await _ref.read(connectionProvider.notifier).reconnect();
    connTrace('device-switch-reconnect',
        'new=$newDeviceId reconnect=${ok ? "ok" : "failed"}');
    if (!ok) {
      print('WebRTC: WS reconnect for device switch failed — UI will surface '
          'reconnect state');
    }
  }

  void _setupWebSocketListeners() {
    final wsClient = _ref.read(websocketClientProvider);

    // Listen for credentials from relay/robot (step 2)
    _subscriptions.add(
      wsClient.webrtcCredentialsStream.listen((message) {
        final iceServers = message['ice_servers'] ?? message['iceServers'];
        // Handle all formats: {iceServers: [...]}, [...], or null/missing (LAN mode)
        Map<String, dynamic> iceServersConfig;
        if (iceServers is List) {
          iceServersConfig = {'iceServers': iceServers};
        } else if (iceServers is Map) {
          iceServersConfig = iceServers as Map<String, dynamic>;
        } else {
          // No ICE servers — LAN mode, use empty list (host candidates only)
          print('WebRTC: No ice_servers in credentials — using empty list (LAN mode)');
          iceServersConfig = {'iceServers': []};
        }
        _handleCredentials(
          message['session_id'] as String? ?? 'local',
          iceServersConfig,
        );
      }),
    );

    // Listen for SDP offers from robot (step 3)
    // If peer connection doesn't exist yet (Pi skipped credentials), create one first
    _subscriptions.add(
      wsClient.webrtcOfferStream.listen((message) async {
        if (_peerConnection == null) {
          print('WebRTC: Received offer but no peer connection — creating with empty ICE servers');
          await _handleCredentials(
            message['session_id'] as String? ?? 'local',
            {'iceServers': []},
          );
        }
        final sdp = message['sdp'];
        if (sdp is Map<String, dynamic>) {
          _handleOffer(sdp);
        } else {
          print('WebRTC: Invalid offer format — sdp field is ${sdp.runtimeType}');
        }
      }),
    );

    // Listen for ICE candidates from robot
    _subscriptions.add(
      wsClient.webrtcIceStream.listen((message) {
        _handleIceCandidate(message['candidate'] as Map<String, dynamic>);
      }),
    );

    // Listen for close messages (robot disconnected) - auto-reconnect
    _subscriptions.add(
      wsClient.webrtcCloseStream.listen((message) async {
        print('WebRTC: Received close from relay, will auto-reconnect');
        await _closeInternal();
        _scheduleReconnect();
      }),
    );

    // Listen for device status changes - auto-request video when device comes online
    _subscriptions.add(
      wsClient.deviceStatusStream.listen((message) {
        final status = message['status'] as String? ?? message['online'] as String?;
        final isOnline = status == 'online' || message['online'] == true;
        final deviceId = message['device_id'] as String?;

        print('WebRTC: Device status - online=$isOnline, deviceId=$deviceId');

        // If device came online and we have a stored device ID, auto-reconnect
        // But not if app is backgrounded, already connected, or already requesting
        if (isOnline && _lastDeviceId != null &&
            state.state != WebRTCState.connected &&
            state.state != WebRTCState.connecting &&
            !_isPaused && !_isRequesting) {
          print('WebRTC: Device came online, requesting video stream');
          _reconnectAttempts = 0;  // Reset attempts for fresh connection
          requestVideoStream(_lastDeviceId!);
        }
      }),
    );
  }

  /// Get the video renderer (initialize if needed)
  Future<RTCVideoRenderer> getRenderer() async {
    if (_renderer == null || !_rendererInitialized) {
      _renderer = RTCVideoRenderer();
      await _renderer!.initialize();
      _rendererInitialized = true;
      _renderer!.onFirstFrameRendered = () {
        connTrace('first-video-frame', 'renderer rendered first frame');
      };
      state = state.copyWith(renderer: _renderer);
    }
    return _renderer!;
  }

  /// Request video stream from robot
  /// Build 44: Enhanced to prevent video bleeding between devices
  Future<void> requestVideoStream(String deviceId) async {
    // Build 44: If switching to a DIFFERENT device, always close first
    final switchingDevice = _lastDeviceId != null && _lastDeviceId != deviceId;

    // Skip if already connected to THIS SAME device
    if (!switchingDevice &&
        _peerConnection != null &&
        _peerConnection!.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      print('WebRTC: Already connected to $deviceId, skipping request');
      return;
    }

    // Prevent concurrent requests from overlapping code paths
    if (_isRequesting) {
      print('WebRTC: Request already in progress, skipping duplicate');
      return;
    }
    _isRequesting = true;

    try {
      print('WebRTC: requestVideoStream for $deviceId (switching=$switchingDevice, prev=$_lastDeviceId)');

      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      // Build 44: Always close existing session when switching devices or if we have one
      if (switchingDevice || _peerConnection != null || state.sessionId != null) {
        print('WebRTC: Closing existing session ${state.sessionId} before new request');
        await _closeInternal();
        // Longer delay when switching devices to ensure relay processes the close
        await Future.delayed(Duration(milliseconds: switchingDevice ? 1000 : 500));
      }

      // Update device ID AFTER closing old session
      _lastDeviceId = deviceId;

      state = state.copyWith(state: WebRTCState.connecting, errorMessage: null);

      // Ensure renderer is initialized
      await getRenderer();

      // Send request to relay
      final wsClient = _ref.read(websocketClientProvider);
      wsClient.send({
        'type': 'webrtc_request',
        'device_id': deviceId,
      });
      print('WebRTC: Sent webrtc_request for device $deviceId');
      connTrace('webrtc-request-sent', 'device=$deviceId');
    } finally {
      _isRequesting = false;
    }
  }

  /// Handle credentials received from relay (step 2)
  Future<void> _handleCredentials(
      String sessionId, Map<String, dynamic> iceServers) async {
    print('WebRTC: Received credentials for session $sessionId');
    state = state.copyWith(sessionId: sessionId);

    try {
      final config = <String, dynamic>{
        'iceServers': iceServers['iceServers'],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(config);

      // Handle incoming tracks from robot (video + audio)
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('WebRTC: Received track: ${event.track.kind}');
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          final stream = event.streams[0];
          connTrace('video-track-recv',
              'stream=${stream.id} tracks=${stream.getVideoTracks().length}');
          print('WebRTC: Setting srcObject with stream id=${stream.id}, tracks=${stream.getVideoTracks().length}');

          if (_renderer != null) {
            _renderer!.srcObject = stream;

            // Log video dimensions after a short delay to let the stream initialize
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_renderer != null) {
                print('WebRTC: Video renderer size: ${_renderer!.videoWidth}x${_renderer!.videoHeight}');
              }
            });
          }

          // Update state with renderer reference to trigger UI rebuild
          state = state.copyWith(
            state: WebRTCState.connected,
            renderer: _renderer,
          );
          print('WebRTC: Video connected, state updated');
        } else if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
          // v1.3: Accept always-on audio track from robot
          _audioStream = event.streams[0];
          print('WebRTC: Audio track received, stream id=${_audioStream!.id}');

          // Apply current mute state to the audio track
          _applyAudioMuteState(state.isAudioMuted);
          print('WebRTC: Audio track initial mute=${state.isAudioMuted}');
        }
      };

      // Handle ICE candidates - send to relay for forwarding to robot
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        final candidateType = _parseIceCandidateType(candidate.candidate);
        print('WebRTC: Local ICE candidate: $candidateType');
        connTrace('ice-candidate', candidateType);
        final wsClient = _ref.read(websocketClientProvider);
        wsClient.send({
          'type': 'webrtc_ice',
          'session_id': state.sessionId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      // Handle connection state changes and auto-reconnect
      _peerConnection!.onConnectionState = (RTCPeerConnectionState connState) {
        print('WebRTC: Connection state: $connState');
        connTrace('pc-state', connState.toString());
        if (connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            connState ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          state = state.copyWith(
            state: WebRTCState.error,
            errorMessage: 'Connection failed',
          );
          // Auto-reconnect if we have a device ID
          _scheduleReconnect();
        } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // Reset reconnect attempts on successful connection
          _reconnectAttempts = 0;
          _reconnectTimer?.cancel();
          // Log the active ICE candidate pair to diagnose relay vs P2P
          _logSelectedCandidatePair();
        }
      };

      // Handle ICE connection state for debugging
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState iceState) {
        print('WebRTC: ICE state: $iceState');
      };

      // ICE gathering progress (diagnostic) — fires 'gathering' when the
      // native stack starts collecting local candidates.
      _peerConnection!.onIceGatheringState = (RTCIceGatheringState gState) {
        connTrace('ice-gathering', gState.toString());
      };

      // Handle incoming data channel from robot (use this one for sending)
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        print('WebRTC: Received data channel from robot: ${channel.label}');
        _dataChannel = channel;  // Store the robot's channel
        _setupDataChannel(channel);
      };

      print('WebRTC: Peer connection created, waiting for offer');
    } catch (e) {
      print('WebRTC: Error creating peer connection: $e');
      state = state.copyWith(
        state: WebRTCState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Handle SDP offer from robot (step 3)
  Future<void> _handleOffer(Map<String, dynamic> sdp) async {
    if (_peerConnection == null) {
      print('WebRTC: ERROR — No peer connection for offer (credentials never arrived or failed)');
      return;
    }

    print('WebRTC: Received offer, creating answer...');
    connTrace('sdp-offer-recv', 'session=${state.sessionId}');

    try {
      final description = RTCSessionDescription(
        sdp['sdp'] as String,
        sdp['type'] as String,
      );

      await _peerConnection!.setRemoteDescription(description);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to robot via relay
      final wsClient = _ref.read(websocketClientProvider);
      wsClient.send({
        'type': 'webrtc_answer',
        'session_id': state.sessionId,
        'sdp': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
      print('WebRTC: Sent answer');
      connTrace('sdp-answer-sent', 'session=${state.sessionId}');
    } catch (e) {
      print('WebRTC: Error handling offer: $e');
      state = state.copyWith(
        state: WebRTCState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Handle ICE candidate from robot
  Future<void> _handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection == null || candidate['candidate'] == null) {
      return;
    }

    final candidateType = _parseIceCandidateType(candidate['candidate'] as String?);
    print('WebRTC: Remote ICE candidate: $candidateType');

    try {
      final iceCandidate = RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      );

      await _peerConnection!.addCandidate(iceCandidate);
    } catch (e) {
      print('WebRTC: Error adding ICE candidate: $e');
    }
  }

  /// Parse ICE candidate type from SDP candidate string
  /// Returns human-readable type: host, srflx (STUN), relay (TURN), or prflx
  String _parseIceCandidateType(String? candidateStr) {
    if (candidateStr == null || candidateStr.isEmpty) return 'empty';
    final match = RegExp(r'typ\s+(\w+)').firstMatch(candidateStr);
    if (match == null) return 'unknown';
    final type = match.group(1)!;
    switch (type) {
      case 'host':
        return 'host (direct LAN)';
      case 'srflx':
        return 'srflx (STUN/NAT traversal)';
      case 'relay':
        return 'relay (TURN server)';
      case 'prflx':
        return 'prflx (peer reflexive)';
      default:
        return type;
    }
  }

  /// Log the selected ICE candidate pair after connection is established.
  /// This tells us whether we're on a direct P2P path or going through TURN relay.
  Future<void> _logSelectedCandidatePair() async {
    if (_peerConnection == null) return;

    try {
      final stats = await _peerConnection!.getStats();
      String? localType;
      String? remoteType;
      String? localAddress;
      String? remoteAddress;
      int? rtt;

      // Collect candidate info from stats
      final localCandidates = <String, Map<String, dynamic>>{};
      final remoteCandidates = <String, Map<String, dynamic>>{};

      for (final report in stats) {
        final values = report.values;
        final type = values['type'] as String?;

        if (type == 'local-candidate') {
          final id = values['id'] as String? ?? report.id;
          localCandidates[id] = Map<String, dynamic>.from(values);
        } else if (type == 'remote-candidate') {
          final id = values['id'] as String? ?? report.id;
          remoteCandidates[id] = Map<String, dynamic>.from(values);
        }
      }

      // Find the active candidate pair
      for (final report in stats) {
        final values = report.values;
        final type = values['type'] as String?;

        if (type == 'candidate-pair' && values['state'] == 'succeeded') {
          final localId = values['localCandidateId'] as String?;
          final remoteId = values['remoteCandidateId'] as String?;
          rtt = values['currentRoundTripTime'] is num
              ? ((values['currentRoundTripTime'] as num) * 1000).round()
              : null;

          if (localId != null && localCandidates.containsKey(localId)) {
            final local = localCandidates[localId]!;
            localType = local['candidateType'] as String?;
            localAddress = '${local['address'] ?? local['ip']}:${local['port']}';
          }
          if (remoteId != null && remoteCandidates.containsKey(remoteId)) {
            final remote = remoteCandidates[remoteId]!;
            remoteType = remote['candidateType'] as String?;
            remoteAddress = '${remote['address'] ?? remote['ip']}:${remote['port']}';
          }
          break; // Only care about the succeeded pair
        }
      }

      // Determine the connection path
      final isRelay = localType == 'relay' || remoteType == 'relay';
      final pathLabel = isRelay
          ? '⚠️ TURN RELAY (adds latency!)'
          : localType == 'host' && remoteType == 'host'
              ? '✅ DIRECT P2P (host-to-host)'
              : '✅ P2P via NAT traversal ($localType → $remoteType)';

      print('');
      print('╔══════════════════════════════════════════╗');
      print('║  WebRTC CONNECTION PATH DIAGNOSTIC       ║');
      print('╠══════════════════════════════════════════╣');
      print('║  Path: $pathLabel');
      print('║  Local:  $localType @ $localAddress');
      print('║  Remote: $remoteType @ $remoteAddress');
      if (rtt != null) {
        print('║  RTT:    ${rtt}ms');
      }
      print('╚══════════════════════════════════════════╝');
      print('');
    } catch (e) {
      print('WebRTC: Error reading stats for candidate pair: $e');
    }
  }

  /// Setup data channel event handlers
  void _setupDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (RTCDataChannelState dcState) {
      print('WebRTC: Data channel "${channel.label}" state: $dcState');
      _dataChannelOpen = dcState == RTCDataChannelState.RTCDataChannelOpen;
      if (_dataChannelOpen) {
        print('WebRTC: Data channel READY for motor commands');
      }
    };

    channel.onMessage = (RTCDataChannelMessage message) {
      _handleDataChannelMessage(message.text);
    };
  }

  /// Dispatch a structured message received from the robot on the WebRTC
  /// data channel. Discriminated union — switch on the `type` field.
  void _handleDataChannelMessage(String text) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        print('WebRTC: Data channel message not a JSON object: $text');
        return;
      }
      json = decoded;
    } catch (e) {
      print('WebRTC: Data channel message not JSON: $text');
      return;
    }

    final type = json['type'] as String?;
    switch (type) {
      case 'video_quality_state':
        // Robot's adaptive-bitrate state — store it for the settings screen.
        _ref.read(videoQualityStateProvider.notifier).updateFromRobot(json);
        break;
      default:
        print('WebRTC: Unhandled data channel message type=$type: $text');
    }
  }

  /// Send motor command via WebRTC data channel (low latency)
  void sendMotorCommand(double left, double right) {
    if (!_dataChannelOpen || _dataChannel == null) {
      print('WebRTC: Cannot send motor - channel not open (open=$_dataChannelOpen, channel=${_dataChannel != null})');
      return;
    }

    final json = jsonEncode({
      'command': 'motor',
      'left': left,
      'right': right,
    });
    print('WebRTC DATA SEND: $json');
    _dataChannel!.send(RTCDataChannelMessage(json));
  }

  /// Send emergency stop via data channel
  void sendEmergencyStop() {
    if (!_dataChannelOpen || _dataChannel == null) {
      return;
    }

    final json = jsonEncode({'command': 'emergency_stop'});
    _dataChannel!.send(RTCDataChannelMessage(json));
  }

  /// Schedule auto-reconnect with exponential backoff
  void _scheduleReconnect() {
    if (_isPaused && !_isVideoOnlyPause) {
      print('WebRTC: Skipping reconnect - app is fully paused');
      return;
    }
    if (_lastDeviceId == null) {
      print('WebRTC: No device ID for reconnect');
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('WebRTC: Max reconnect attempts reached');
      state = state.copyWith(
        state: WebRTCState.error,
        errorMessage: 'Connection failed - tap to retry',
      );
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(
      milliseconds: _reconnectDelay.inMilliseconds * _reconnectAttempts,
    );

    print('WebRTC: Auto-reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      if (_isPaused && !_isVideoOnlyPause) {
        print('WebRTC: Reconnect timer fired but app is fully paused, skipping');
        return;
      }
      if (_isRequesting) {
        print('WebRTC: Reconnect timer fired but request already in progress, skipping');
        return;
      }
      if (_lastDeviceId != null && state.state != WebRTCState.connected) {
        // requestVideoStream now handles closing existing session internally
        await requestVideoStream(_lastDeviceId!);
      }
    });
  }

  /// Retry connection after max attempts reached (user-initiated)
  Future<void> retryConnection() async {
    if (_lastDeviceId == null) return;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await requestVideoStream(_lastDeviceId!);
  }

  /// Internal close without clearing device ID (for reconnect)
  /// Build 44: More thorough cleanup to prevent video bleeding
  Future<void> _closeInternal() async {
    print('WebRTC: _closeInternal - stopping all streams and connections');
    cancelAutoListen();

    // Build 44: Clear renderer FIRST to immediately stop showing old video
    if (_renderer != null && _renderer!.srcObject != null) {
      print('WebRTC: Stopping and clearing renderer stream');
      // Stop all tracks on the stream before clearing
      final stream = _renderer!.srcObject;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          print('WebRTC: Stopping track ${track.kind}');
          track.stop();
        }
      }
      _renderer!.srcObject = null;
    }

    // Send close message to relay
    if (state.sessionId != null) {
      try {
        final wsClient = _ref.read(websocketClientProvider);
        wsClient.send({
          'type': 'webrtc_close',
          'session_id': state.sessionId,
        });
        print('WebRTC: Sent webrtc_close for session ${state.sessionId}');
      } catch (e) {
        print('WebRTC: Error sending close message: $e');
      }
    }

    // Clear audio stream reference
    _audioStream = null;

    // Close data channel first (before peer connection)
    if (_dataChannel != null) {
      try {
        await _dataChannel!.close();
        print('WebRTC: Data channel closed');
      } catch (_) {
        // Ignore - already closed or peer connection null
      }
      _dataChannel = null;
    }
    _dataChannelOpen = false;

    // Close peer connection
    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        print('WebRTC: Peer connection closed');
      } catch (_) {
        // Ignore - already closed
      }
      _peerConnection = null;
    }

    state = state.copyWith(
      state: WebRTCState.disconnected,
      sessionId: null,
    );
    // Robot's video-quality state is per-session — clear it so the settings
    // screen shows "not connected" instead of stale data.
    _ref.read(videoQualityStateProvider.notifier).clear();
    print('WebRTC: _closeInternal complete - state is disconnected');
  }

  /// Pause WebRTC when app is backgrounded.
  /// Closes the connection cleanly and suppresses reconnection attempts.
  /// Preserves _lastDeviceId so resume() can reconnect.
  Future<void> pause() async {
    if (_isPaused) return;
    _isPaused = true;
    _isVideoOnlyPause = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRequesting = false;
    print('WebRTC: Paused (app backgrounded) - closing connection, suppressing reconnects');
    await _closeInternal();
  }

  /// Pause only video tracks when app is backgrounded (background audio mode).
  /// Keeps peer connection, audio tracks, and data channel alive.
  void pauseVideoOnly() {
    if (_isPaused) return;
    _isPaused = true;
    _isVideoOnlyPause = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    // Disable video tracks only — keep audio alive
    if (_renderer?.srcObject != null) {
      for (final track in _renderer!.srcObject!.getVideoTracks()) {
        track.enabled = false;
        print('WebRTC: Disabled video track for background');
      }
    }

    print('WebRTC: Video paused (background audio active)');
  }

  /// Resume WebRTC when app returns to foreground.
  /// Re-enables video tracks if video-only pause, or reconnects if full pause.
  Future<void> resume() async {
    if (!_isPaused) return;

    if (_isVideoOnlyPause) {
      // Video-only pause: just re-enable video tracks
      _isPaused = false;
      _isVideoOnlyPause = false;

      if (_renderer?.srcObject != null) {
        for (final track in _renderer!.srcObject!.getVideoTracks()) {
          track.enabled = true;
          print('WebRTC: Re-enabled video track');
        }
      }

      print('WebRTC: Resumed video (was background audio)');
    } else {
      // Full pause: reconnect
      _isPaused = false;
      print('WebRTC: Resumed (app foregrounded)');

      if (_lastDeviceId != null) {
        print('WebRTC: Reconnecting to $_lastDeviceId');
        _reconnectAttempts = 0;
        await requestVideoStream(_lastDeviceId!);
      }
    }
  }

  /// Close the WebRTC connection (manual close - stops auto-reconnect)
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRequesting = false;
    _lastDeviceId = null;  // Clear to prevent auto-reconnect
    await _closeInternal();
  }

  /// B4: Hard teardown — wipes peer connection, ICE buffers, and all state.
  /// Called before resuming a connection where the WS may have died while
  /// backgrounded. We do NOT clear `_lastDeviceId` so a subsequent
  /// `requestVideoStream` still knows the target. Also forces `_isPaused=false`
  /// so the next reconnect attempt can fire.
  Future<void> hardTeardown() async {
    print('WebRTC: hardTeardown — forcing full reset before reconnect');
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRequesting = false;
    _isPaused = false;
    _isVideoOnlyPause = false;
    await _closeInternal();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _autoListenTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    close();
    _renderer?.dispose();
    super.dispose();
  }
}
