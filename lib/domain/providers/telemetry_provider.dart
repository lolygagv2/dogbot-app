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
    // Build 42: Capture current battery BEFORE any updates to ensure we never lose it
    final previousBattery = state.battery;

    // Debug: log all events to trace battery data
    print('Telemetry event: type=${event.type}, prevBattery=$previousBattery, data=${event.data}');

    // Check for battery data in ANY event (robot might send it in various formats)
    _extractBatteryFromAnyEvent(event.data);

    switch (event.type) {
      case 'telemetry':
      case 'status':
      case 'robot_status':
      case 'status_update':  // Combined status from robot
        // Full status update - parse but preserve existing values if not in this event
        final parsed = Telemetry.fromApiResponse(event.data);
        // Only update mode if it was actually in the event data (not defaulted to 'idle')
        final hasMode = event.data.containsKey('mode') && event.data['mode'] != null;

        // Build 42: Check if battery was actually in this event's data
        final hasBatteryData = event.data.containsKey('battery') ||
                               event.data.containsKey('level') ||
                               (event.data['battery'] is Map);
        // Use parsed battery only if it's > 0, otherwise keep previous value
        final newBattery = parsed.battery > 0 ? parsed.battery :
                          (state.battery > 0 ? state.battery : previousBattery);

        state = state.copyWith(
          battery: newBattery,
          temperature: parsed.temperature > 0 ? parsed.temperature : state.temperature,
          // Preserve existing mode if not in this event
          mode: hasMode ? parsed.mode : state.mode,
          dogDetected: parsed.dogDetected,
          currentBehavior: parsed.currentBehavior,
          confidence: parsed.confidence,
          isCharging: hasBatteryData ? parsed.isCharging : state.isCharging,
          treatsRemaining: parsed.treatsRemaining > 0 ? parsed.treatsRemaining : state.treatsRemaining,
          activeMissionId: parsed.activeMissionId,
          rawData: parsed.rawData,
        );
        print('Telemetry updated (${event.type}): battery=${state.battery}, mode=${state.mode}, hasBattery=$hasBatteryData');
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
        // Battery update - {'level': 95, 'charging': true, 'voltage': 16.6, 'temperature': 73.25, 'treats_today': 0, 'mode': 'idle'}
        final level = (event.data['level'] as num?)?.toDouble();
        final charging = event.data['charging'] as bool?;
        final temp = (event.data['temperature'] as num?)?.toDouble();
        final treats = event.data['treats_today'] as int?;
        final mode = event.data['mode'] as String?;
        print('BATTERY EVENT RECEIVED: level=$level, charging=$charging, temp=$temp, treats=$treats, mode=$mode');
        if (level != null) {
          state = state.copyWith(
            battery: level,
            isCharging: charging ?? state.isCharging,
            temperature: temp ?? state.temperature,
            treatsRemaining: treats ?? state.treatsRemaining,
            mode: mode ?? state.mode,
          );
          print('STATE UPDATED: battery=${state.battery}, temp=${state.temperature}, treats=${state.treatsRemaining}, mode=${state.mode}');
        }
        break;

      case 'bark':
        // Bark detected - handled silently here, guardian_events_provider picks it up
        // from the websocket eventStream directly
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

  /// Extract telemetry data from any event - robot sends it in various formats
  /// Build 42: Only updates if valid battery data found, never resets to 0
  void _extractBatteryFromAnyEvent(Map<String, dynamic> data) {
    // Format 1: {'level': 96, 'charging': true, 'voltage': 16.6, 'temperature': 73.25, 'treats_today': 0}
    if (data.containsKey('level')) {
      final level = (data['level'] as num?)?.toDouble();
      final charging = data['charging'] as bool?;
      final temp = (data['temperature'] as num?)?.toDouble();
      final treats = data['treats_today'] as int?;
      if (level != null && level > 0) {
        print('BATTERY EXTRACTED (level key): level=$level, charging=$charging, temp=$temp, treats=$treats');
        state = state.copyWith(
          battery: level,
          isCharging: charging ?? state.isCharging,
          temperature: temp ?? state.temperature,
          treatsRemaining: treats ?? state.treatsRemaining,
        );
      }
      return;
    }

    // Format 2: {'battery': {'level': 96, 'charging': true}}
    final batteryData = data['battery'];
    if (batteryData is Map) {
      final level = (batteryData['level'] as num?)?.toDouble();
      final charging = batteryData['charging'] as bool?;
      final temp = (batteryData['temperature'] as num?)?.toDouble();
      final treats = batteryData['treats_today'] as int?;
      if (level != null && level > 0) {
        print('BATTERY EXTRACTED (nested): level=$level, temp=$temp');
        state = state.copyWith(
          battery: level,
          isCharging: charging ?? state.isCharging,
          temperature: temp ?? state.temperature,
          treatsRemaining: treats ?? state.treatsRemaining,
        );
      }
      return;
    }

    // Format 3: {'battery': 96} (just a number)
    if (batteryData is num && batteryData > 0) {
      print('BATTERY EXTRACTED (number): level=$batteryData');
      state = state.copyWith(battery: batteryData.toDouble());
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
