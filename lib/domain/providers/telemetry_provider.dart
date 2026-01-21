import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/environment.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/websocket_client.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/telemetry.dart';
import 'connection_provider.dart';

/// Provider for current telemetry data
final telemetryProvider =
    StateNotifierProvider<TelemetryNotifier, Telemetry>((ref) {
  return TelemetryNotifier(ref);
});

/// Telemetry state notifier - combines polling + WebSocket updates
class TelemetryNotifier extends StateNotifier<Telemetry> {
  final Ref _ref;
  Timer? _pollTimer;
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
    // WebSocket events for real-time updates (used in both modes)
    _wsSubscription?.cancel();
    _wsSubscription =
        _ref.read(websocketClientProvider).eventStream.listen(_handleWsEvent);

    // In cloud/production mode, rely only on WebSocket events from relay
    // No direct REST polling to robot
    if (AppConfig.env == Environment.prod) {
      print('Cloud mode: telemetry via WebSocket only');
      return;
    }

    // Dev mode: also use REST polling for direct robot connection
    refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      AppConstants.telemetryRefreshInterval,
      (_) => refresh(),
    );
  }

  void _stopListening() {
    _pollTimer?.cancel();
    _wsSubscription?.cancel();
  }

  void _handleWsEvent(WsEvent event) {
    switch (event.event) {
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

  /// Manually refresh telemetry from API (dev mode only)
  /// In cloud mode, telemetry comes via WebSocket events
  Future<void> refresh() async {
    // Skip REST polling in cloud mode - telemetry comes via WebSocket
    if (AppConfig.env == Environment.prod) return;

    if (!_ref.read(connectionProvider).isConnected) return;

    try {
      final api = _ref.read(robotApiProvider);
      final telemetry = await api.getTelemetry();
      state = telemetry;
    } catch (e) {
      print('Telemetry refresh error: $e');
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
