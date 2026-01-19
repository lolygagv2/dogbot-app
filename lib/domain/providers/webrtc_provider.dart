import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/services/webrtc_service.dart';

/// Provider for WebRTC state
final webrtcStateProvider = StateProvider<WebRTCState>((ref) {
  return WebRTCState.disconnected;
});

/// Provider for the WebRTC service instance
/// Returns null if WebSocket is not connected
final webrtcServiceProvider = Provider<WebRTCService?>((ref) {
  final wsClient = ref.watch(websocketClientProvider);

  if (wsClient.state != WsConnectionState.connected) {
    return null;
  }

  final service = WebRTCService(
    onSendMessage: (message) => wsClient.send(message),
    onStateChange: (state) {
      // Update the state provider when WebRTC state changes
      ref.read(webrtcStateProvider.notifier).state = state;
    },
  );

  ref.onDispose(() => service.dispose());

  return service;
});
