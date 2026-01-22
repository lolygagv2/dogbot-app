import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/telemetry.dart';

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
    print('TelemetryNotifier: Created, subscribing to events immediately');

    // Always subscribe to WebSocket events - process them when they arrive
    final wsClient = _ref.read(websocketClientProvider);
    _wsSubscription = wsClient.eventStream.listen(_handleWsEvent);
    print('TelemetryNotifier: Subscribed to eventStream');
  }

  void _stopListening() {
    _wsSubscription?.cancel();
  }

  void _handleWsEvent(WsEvent event) {
    // Debug: log all events to trace battery data
    print('Telemetry event: type=${event.type}, data=${event.data}');

    switch (event.type) {
      case 'telemetry':
      case 'status':
      case 'robot_status':
        // Full status update - may include battery
        state = Telemetry.fromApiResponse(event.data);
        print('Telemetry updated: battery=${state.battery}, charging=${state.isCharging}');
        break;

      case 'device_status':
        // Device status may include battery info
        _handleDeviceStatus(event.data);
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
        // Battery update - {'level': 95, 'charging': true, 'voltage': 16.6}
        final level = (event.data['level'] as num?)?.toDouble();
        final charging = event.data['charging'] as bool?;
        print('BATTERY EVENT RECEIVED: level=$level, charging=$charging, raw=${event.data}');
        if (level != null) {
          state = state.copyWith(
            battery: level,
            isCharging: charging ?? state.isCharging,
          );
          print('BATTERY STATE UPDATED: battery=${state.battery}, isCharging=${state.isCharging}');
        }
        break;

      case 'mode':
        // Mode change
        state = state.copyWith(
          mode: event.data['mode'] as String? ?? state.mode,
        );
        break;

      default:
        // Log unhandled event types to help debugging
        print('Telemetry: Unhandled event type: ${event.type}');
    }
  }

  void _handleDeviceStatus(Map<String, dynamic> data) {
    // Device status may include nested battery data
    final batteryData = data['battery'];
    if (batteryData is Map) {
      final level = (batteryData['level'] as num?)?.toDouble();
      final charging = batteryData['charging'] as bool?;
      print('Device status battery: level=$level, charging=$charging');
      if (level != null) {
        state = state.copyWith(
          battery: level,
          isCharging: charging ?? state.isCharging,
        );
      }
    } else if (batteryData is num) {
      state = state.copyWith(battery: batteryData.toDouble());
    }

    // Also check for mode
    final mode = data['mode'] as String?;
    if (mode != null) {
      state = state.copyWith(mode: mode);
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
