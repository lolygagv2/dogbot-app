import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC connection state
enum WebRTCState { disconnected, connecting, connected, error }

/// WebRTC service for video streaming via relay server
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  String? _sessionId;
  WebRTCState _state = WebRTCState.disconnected;

  // Callbacks for sending messages via WebSocket
  final void Function(Map<String, dynamic>) onSendMessage;
  final void Function(WebRTCState) onStateChange;

  WebRTCService({
    required this.onSendMessage,
    required this.onStateChange,
  });

  WebRTCState get state => _state;
  String? get sessionId => _sessionId;
  bool get isConnected => _state == WebRTCState.connected;

  /// Initialize the video renderer
  Future<void> initialize() async {
    await remoteRenderer.initialize();
  }

  void _setState(WebRTCState newState) {
    _state = newState;
    onStateChange(newState);
  }

  /// Request video stream from relay server
  Future<void> requestVideoStream(String deviceId) async {
    _setState(WebRTCState.connecting);

    onSendMessage({
      'type': 'webrtc_request',
      'device_id': deviceId,
    });
  }

  /// Handle credentials received from relay (step 2 of signaling flow)
  Future<void> handleCredentials(
      String sessionId, Map<String, dynamic> iceServers) async {
    _sessionId = sessionId;

    try {
      final config = <String, dynamic>{
        'iceServers': iceServers['iceServers'],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(config);

      // Handle incoming video track from robot
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          _setState(WebRTCState.connected);
        }
      };

      // Handle ICE candidates - send to relay for forwarding to robot
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        onSendMessage({
          'type': 'webrtc_ice',
          'session_id': _sessionId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      // Handle connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('WebRTC connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setState(WebRTCState.error);
        }
      };

      // Handle ICE connection state for debugging
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE connection state: $state');
      };
    } catch (e) {
      print('Error creating peer connection: $e');
      _setState(WebRTCState.error);
    }
  }

  /// Handle SDP offer from robot (step 3 of signaling flow)
  Future<void> handleOffer(Map<String, dynamic> sdp) async {
    if (_peerConnection == null) {
      print('No peer connection available for offer');
      return;
    }

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
      onSendMessage({
        'type': 'webrtc_answer',
        'session_id': _sessionId,
        'sdp': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
    } catch (e) {
      print('Error handling offer: $e');
      _setState(WebRTCState.error);
    }
  }

  /// Handle ICE candidate from robot
  Future<void> handleIceCandidate(Map<String, dynamic> candidate) async {
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
      print('Error adding ICE candidate: $e');
    }
  }

  /// Close the WebRTC connection
  Future<void> close() async {
    if (_sessionId != null) {
      onSendMessage({
        'type': 'webrtc_close',
        'session_id': _sessionId,
      });
    }

    await _peerConnection?.close();
    _peerConnection = null;
    _sessionId = null;
    remoteRenderer.srcObject = null;

    _setState(WebRTCState.disconnected);
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await close();
    await remoteRenderer.dispose();
  }
}
