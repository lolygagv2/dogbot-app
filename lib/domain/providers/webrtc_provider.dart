import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/network/websocket_client.dart';

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
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Whether the data channel is ready for sending
  bool get isDataChannelOpen => _dataChannelOpen;

  WebRTCNotifier(this._ref) : super(const WebRTCConnectionState()) {
    _setupWebSocketListeners();
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
        if (isOnline && _lastDeviceId != null && state.state != WebRTCState.connected) {
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
    _lastDeviceId = deviceId;  // Store for auto-reconnect
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();

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
          _renderer?.srcObject = event.streams[0];
          state = state.copyWith(state: WebRTCState.connected);
          print('WebRTC: Video connected');
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
      if (_lastDeviceId != null && state.state != WebRTCState.connected) {
        // Close existing connection cleanly
        await _closeInternal();
        // Request new session
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

    // Close data channel with null check and error handling
    if (_dataChannel != null) {
      try {
        _dataChannel!.close();
      } catch (e) {
        print('WebRTC: Error closing data channel: $e');
      }
      _dataChannel = null;
    }
    _dataChannelOpen = false;

    // Close peer connection with null check and error handling
    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
      } catch (e) {
        print('WebRTC: Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    _renderer?.srcObject = null;

    state = state.copyWith(
      state: WebRTCState.disconnected,
      sessionId: null,
    );
  }

  /// Close the WebRTC connection (manual close - stops auto-reconnect)
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
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
