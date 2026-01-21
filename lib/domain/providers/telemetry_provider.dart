import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/telemetry.dart';
import 'connection_provider.dart';

/// Provider for current telemetry data
final telemetryProvider =
    StateNotifierProvider<TelemetryNotifier, Telemetry>((ref) {
  return TelemetryNotifier(ref);
});

/// Telemetry state notifier - receives updates via WebSocket only
/// All telemetry comes from the relay server via WebSocket events
class TelemetryNotifier extends StateNotifier<Telemetry> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  TelemetryNotifier(this._ref) : super(const Telemetry()) {
    // Watch connection state
    _ref.listen<ConnectionState>(connectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        _startListening();
      } else if (!next.isConnected) {
        _stopListening();
      }
    });

    // Start if already connected
    if (_ref.read(connectionProvider).isConnected) {
      _startListening();
    }
  }

  void _startListening() {
    // All telemetry comes via WebSocket events from relay
    _wsSubscription?.cancel();
    _wsSubscription =
        _ref.read(websocketClientProvider).eventStream.listen(_handleWsEvent);
    print('Telemetry: listening via WebSocket');
  }

  void _stopListening() {
    _wsSubscription?.cancel();
  }

  void _handleWsEvent(WsEvent event) {
    switch (event.type) {
      case 'telemetry':
      case 'status':
        // Full status update
        state = Telemetry.fromApiResponse(event.data);
        break;

      case 'detection':
        // Dog detection update
        final detection = Detection.fromWsEvent(event.data);
        state = state.copyWith(
          dogDetected: detection.detected,
          currentBehavior: detection.behavior,
          confidence: detection.confidence,
        );
        break;

      case 'treat':
        // Treat dispensed
        state = state.copyWith(
          treatsRemaining: event.data['remaining'] as int? ?? state.treatsRemaining,
          lastTreatTime: DateTime.now(),
        );
        break;

      case 'battery':
        // Battery update
        state = state.copyWith(
          battery: (event.data['level'] as num?)?.toDouble() ?? state.battery,
          isCharging: event.data['charging'] as bool? ?? state.isCharging,
        );
        break;

      case 'mode':
        // Mode change
        state = state.copyWith(
          mode: event.data['mode'] as String? ?? state.mode,
        );
        break;
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}

/// Provider for latest detection data
final detectionProvider = Provider<Detection>((ref) {
  final telemetry = ref.watch(telemetryProvider);
  return Detection(
    detected: telemetry.dogDetected,
    behavior: telemetry.currentBehavior,
    confidence: telemetry.confidence,
    timestamp: DateTime.now(),
  );
});

/// Provider for battery level
final batteryProvider = Provider<double>((ref) {
  return ref.watch(telemetryProvider).battery;
});

/// Provider for current mode
final modeProvider = Provider<String>((ref) {
  return ref.watch(telemetryProvider).mode;
});
