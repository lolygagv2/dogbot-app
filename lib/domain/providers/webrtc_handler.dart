import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import 'webrtc_provider.dart';

/// Handles WebRTC signaling messages from WebSocket
/// Bridges WebSocket events to WebRTC service
class WebRTCHandler {
  final Ref _ref;
  final List<StreamSubscription> _subscriptions = [];

  WebRTCHandler(this._ref) {
    _setupListeners();
  }

  void _setupListeners() {
    final wsClient = _ref.read(websocketClientProvider);

    // Listen for credentials from relay (step 2)
    _subscriptions.add(
      wsClient.webrtcCredentialsStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleCredentials(
          message['session_id'] as String,
          message['ice_servers'] as Map<String, dynamic>,
        );
      }),
    );

    // Listen for SDP offers from robot (step 3)
    _subscriptions.add(
      wsClient.webrtcOfferStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleOffer(message['sdp'] as Map<String, dynamic>);
      }),
    );

    // Listen for ICE candidates from robot
    _subscriptions.add(
      wsClient.webrtcIceStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleIceCandidate(message['candidate'] as Map<String, dynamic>);
      }),
    );

    // Listen for close messages
    _subscriptions.add(
      wsClient.webrtcCloseStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.close();
      }),
    );
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
  }
}

/// Provider for WebRTC handler - auto-initializes when accessed
final webrtcHandlerProvider = Provider((ref) {
  final handler = WebRTCHandler(ref);
  ref.onDispose(() => handler.dispose());
  return handler;
});
