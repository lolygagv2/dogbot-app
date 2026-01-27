import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/network/websocket_client.dart';
import 'device_provider.dart';

/// WebRTC connection state
enum WebRTCState { disconnected, connecting, connected, error }

/// WebRTC state with renderer
class WebRTCConnectionState {
  final WebRTCState state;
  final RTCVideoRenderer? renderer;
  final String? sessionId;
  final String? errorMessage;

  const WebRTCConnectionState({
    this.state = WebRTCState.disconnected,
    this.renderer,
    this.sessionId,
    this.errorMessage,
  });

  WebRTCConnectionState copyWith({
    WebRTCState? state,
    RTCVideoRenderer? renderer,
    String? sessionId,
    String? errorMessage,
  }) {
    return WebRTCConnectionState(
      state: state ?? this.state,
      renderer: renderer ?? this.renderer,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage,
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

/// WebRTC state notifier - manages peer connection and video rendering
class WebRTCNotifier extends StateNotifier<WebRTCConnectionState> {
  final Ref _ref;
  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _renderer;
  RTCDataChannel? _dataChannel;
  final List<StreamSubscription> _subscriptions = [];
  bool _rendererInitialized = false;
  bool _dataChannelOpen = false;
  String? _lastDeviceId;  // Store for auto-reconnect
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isPaused = false;  // True when app is backgrounded
  bool _isRequesting = false;  // Guard against concurrent requestVideoStream calls
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Whether the data channel is ready for sending
  bool get isDataChannelOpen => _dataChannelOpen;

  /// Whether WebRTC is paused (app backgrounded)
  bool get isPaused => _isPaused;

  WebRTCNotifier(this._ref) : super(const WebRTCConnectionState()) {
    _setupWebSocketListeners();
    _setupDeviceIdListener();
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

  /// Handle device switch - tear down old connection and establish new one
  Future<void> _handleDeviceSwitch(String newDeviceId) async {
    // Only switch if we have an active or pending connection
    if (_lastDeviceId == null && state.state == WebRTCState.disconnected) {
      print('WebRTC: No active connection, just updating device ID');
      _lastDeviceId = newDeviceId;
      return;
    }

    print('WebRTC: Switching video from $_lastDeviceId to $newDeviceId');

    // Cancel any pending reconnect
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    // requestVideoStream handles closing existing session internally
    await requestVideoStream(newDeviceId);
  }

  void _setupWebSocketListeners() {
    final wsClient = _ref.read(websocketClientProvider);

    // Listen for credentials from relay (step 2)
    _subscriptions.add(
      wsClient.webrtcCredentialsStream.listen((message) {
        final iceServers = message['ice_servers'];
        // Handle both formats: {iceServers: [...]} or just [...]
        final iceServersConfig = iceServers is List
            ? {'iceServers': iceServers}
            : (iceServers as Map<String, dynamic>);
        _handleCredentials(
          message['session_id'] as String,
          iceServersConfig,
        );
      }),
    );

    // Listen for SDP offers from robot (step 3)
    _subscriptions.add(
      wsClient.webrtcOfferStream.listen((message) {
        _handleOffer(message['sdp'] as Map<String, dynamic>);
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
      state = state.copyWith(renderer: _renderer);
    }
    return _renderer!;
  }

  /// Request video stream from robot
  Future<void> requestVideoStream(String deviceId) async {
    // Skip if already connected to this device
    if (_peerConnection != null &&
        _peerConnection!.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      print('WebRTC: Already connected, skipping request');
      return;
    }

    // Prevent concurrent requests from overlapping code paths
    if (_isRequesting) {
      print('WebRTC: Request already in progress, skipping duplicate');
      return;
    }
    _isRequesting = true;

    try {
      _lastDeviceId = deviceId;  // Store for auto-reconnect
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      // Close existing session before requesting new one
      if (_peerConnection != null || state.sessionId != null) {
        print('WebRTC: Closing existing session ${state.sessionId} before new request');
        await _closeInternal();
        // Small delay to ensure relay processes the close
        await Future.delayed(const Duration(milliseconds: 500));
      }

      state = state.copyWith(state: WebRTCState.connecting, errorMessage: null);

      // Ensure renderer is initialized
      await getRenderer();

      // Send request to relay
      final wsClient = _ref.read(websocketClientProvider);
      wsClient.send({
        'type': 'webrtc_request',
        'device_id': deviceId,
      });
      print('WebRTC: Sent request for device $deviceId');
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

      // Handle incoming video track from robot
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('WebRTC: Received track: ${event.track.kind}');
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          final stream = event.streams[0];
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
        }
      };

      // Handle ICE candidates - send to relay for forwarding to robot
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
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
        }
      };

      // Handle ICE connection state for debugging
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState iceState) {
        print('WebRTC: ICE state: $iceState');
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
      print('WebRTC: No peer connection for offer');
      return;
    }

    print('WebRTC: Received offer');

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
      print('WebRTC: Data channel message: ${message.text}');
    };
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
    if (_isPaused) {
      print('WebRTC: Skipping reconnect - app is backgrounded');
      return;
    }
    if (_lastDeviceId == null) {
      print('WebRTC: No device ID for reconnect');
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('WebRTC: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(
      milliseconds: _reconnectDelay.inMilliseconds * _reconnectAttempts,
    );

    print('WebRTC: Auto-reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      if (_isPaused) {
        print('WebRTC: Reconnect timer fired but app is backgrounded, skipping');
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

  /// Internal close without clearing device ID (for reconnect)
  Future<void> _closeInternal() async {
    if (state.sessionId != null) {
      try {
        final wsClient = _ref.read(websocketClientProvider);
        wsClient.send({
          'type': 'webrtc_close',
          'session_id': state.sessionId,
        });
      } catch (e) {
        print('WebRTC: Error sending close message: $e');
      }
    }

    // Close data channel first (before peer connection)
    if (_dataChannel != null) {
      try {
        await _dataChannel!.close();
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
      } catch (_) {
        // Ignore - already closed
      }
      _peerConnection = null;
    }

    _renderer?.srcObject = null;

    state = state.copyWith(
      state: WebRTCState.disconnected,
      sessionId: null,
    );
  }

  /// Pause WebRTC when app is backgrounded.
  /// Closes the connection cleanly and suppresses reconnection attempts.
  /// Preserves _lastDeviceId so resume() can reconnect.
  Future<void> pause() async {
    if (_isPaused) return;
    _isPaused = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRequesting = false;
    print('WebRTC: Paused (app backgrounded) - closing connection, suppressing reconnects');
    await _closeInternal();
  }

  /// Resume WebRTC when app returns to foreground.
  /// Reconnects to the last device if we had an active session.
  Future<void> resume() async {
    if (!_isPaused) return;
    _isPaused = false;
    print('WebRTC: Resumed (app foregrounded)');

    // Reconnect if we had a previous device
    if (_lastDeviceId != null) {
      print('WebRTC: Reconnecting to $_lastDeviceId');
      _reconnectAttempts = 0;
      await requestVideoStream(_lastDeviceId!);
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

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    close();
    _renderer?.dispose();
    super.dispose();
  }
}
