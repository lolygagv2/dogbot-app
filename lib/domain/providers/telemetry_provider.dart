import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/models/telemetry.dart';
import 'dog_profiles_provider.dart';

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

  /// Behavior labels are point-in-time readings, not persistent state. The
  /// robot classifies at ~2-3 Hz while it can see the dog; when no fresh
  /// behavior event has arrived within this window, the displayed behavior +
  /// confidence are cleared (matches allDetectionsProvider's box pruning).
  static const Duration _behaviorStaleAfter = Duration(seconds: 2);
  Timer? _behaviorStaleTimer;
  DateTime? _behaviorFreshAt;

  TelemetryNotifier(this._ref) : super(const Telemetry()) {
    print('TelemetryNotifier: Created, subscribing to events immediately');

    // Always subscribe to WebSocket events - process them when they arrive
    final wsClient = _ref.read(websocketClientProvider);
    _wsSubscription = wsClient.eventStream.listen(_handleWsEvent);
    print('TelemetryNotifier: Subscribed to eventStream');

    _behaviorStaleTimer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _expireStaleBehavior());
  }

  void _stopListening() {
    _wsSubscription?.cancel();
    _behaviorStaleTimer?.cancel();
  }

  /// Clear behavior/confidence/dog-detected once the last reading is stale.
  /// Also resets lastDetectionProvider so derived providers (detectionProvider,
  /// unknownDogProvider) stop reporting a dog that left the frame.
  void _expireStaleBehavior() {
    final fresh = _behaviorFreshAt;
    if (fresh == null) return;
    if (DateTime.now().difference(fresh) < _behaviorStaleAfter) return;
    _behaviorFreshAt = null;
    if (state.currentBehavior != null ||
        state.confidence != null ||
        state.dogDetected) {
      state = state.copyWith(
        currentBehavior: null,
        confidence: null,
        dogDetected: false,
      );
    }
    _ref.read(lastDetectionProvider.notifier).state = const Detection();
  }

  @visibleForTesting
  void debugHandleEvent(WsEvent event) => _handleWsEvent(event);

  @visibleForTesting
  void debugSetBehaviorFreshAt(DateTime t) => _behaviorFreshAt = t;

  @visibleForTesting
  void debugExpireStaleBehavior() => _expireStaleBehavior();

  void _handleWsEvent(WsEvent event) {
    // Debug: log event type
    print('Telemetry event: type=${event.type}, battery_before=${state.battery}');

    // Check for battery data in ANY event (robot might send it in various formats)
    // This updates state.battery if found
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

        // Build 44: Use state.battery (may have been updated by _extractBatteryFromAnyEvent)
        // Only use parsed.battery if it's > 0, otherwise keep current state
        final batteryToUse = parsed.battery > 0 ? parsed.battery : state.battery;

        state = state.copyWith(
          battery: batteryToUse,
          temperature: parsed.temperature > 0 ? parsed.temperature : state.temperature,
          // Preserve existing mode if not in this event
          mode: hasMode ? parsed.mode : state.mode,
          dogDetected: parsed.dogDetected,
          currentBehavior: parsed.currentBehavior,
          confidence: parsed.confidence,
          // Only update isCharging if we got battery data
          isCharging: parsed.battery > 0 ? parsed.isCharging : state.isCharging,
          // Only update treat counter fields if this event actually had them.
          treatsRemaining: parsed.treatsRemaining != kTreatCountUnknown
              ? parsed.treatsRemaining
              : state.treatsRemaining,
          treatsGiven: parsed.treatsGiven != kTreatCountUnknown
              ? parsed.treatsGiven
              : state.treatsGiven,
          activeMissionId: parsed.activeMissionId,
          connectionType: parsed.connectionType ?? state.connectionType,
          // OTA: robot's running release version — preserve if absent.
          swVersion: parsed.swVersion ?? state.swVersion,
          // Robot's VolumeManager value — preserve if absent from this event.
          volume: parsed.volume ?? state.volume,
          rawData: parsed.rawData,
        );
        // Treat counter: the shared applier derives remaining from a
        // given-only frame and traces changes for on-device diagnostics.
        _applyTreatCounterFields(event.data, event.type);
        // A status frame carrying a behavior is a fresh point-in-time reading.
        if (parsed.currentBehavior != null || parsed.dogDetected) {
          _behaviorFreshAt = DateTime.now();
        }
        print('Telemetry updated (${event.type}): battery=${state.battery}, mode=${state.mode}');
        break;

      case 'device_status':
        // Device status may include battery info
        _handleDeviceStatus(event.data);
        break;

      case 'detection':
        // Dog detection update — store full detection with dogName/arucoId
        final detection = Detection.fromWsEvent(event.data);
        _ref.read(lastDetectionProvider.notifier).state = detection;
        // C5: also update the multi-dog map so the UI can render boxes/chips
        // for every dog visible this frame, not just the most recent.
        _ref.read(allDetectionsProvider.notifier).upsert(detection);
        state = state.copyWith(
          dogDetected: detection.detected,
          currentBehavior: detection.behavior,
          confidence: detection.confidence,
        );
        if (detection.detected) _behaviorFreshAt = DateTime.now();
        break;

      case 'unknown_dog_detected':
        // Robot detected ArUco marker with no profile — store as detection
        // so unknownDogProvider can trigger the "Add dog?" prompt
        final arucoId = event.data['aruco_id'] as int?;
        if (arucoId != null) {
          _ref.read(lastDetectionProvider.notifier).state = Detection(
            detected: true,
            arucoId: arucoId,
            timestamp: DateTime.now(),
          );
        }
        break;

      case 'treat':
        // Treat dispensed (legacy format)
        _applyTreatCounterFields(event.data, event.type);
        state = state.copyWith(
          treatsRemaining:
              asLenientInt(event.data['remaining']) ?? state.treatsRemaining,
          lastTreatTime: DateTime.now(),
        );
        break;

      case 'treat_status':
      // Robot 8e8c91c: treats_low / treats_loaded / treats_empty events now
      // carry treats_given + treat_capacity alongside treats_remaining.
      // treats_empty is latched robot-side (fires once, cleared by refill/
      // reset), so no dedup is needed here.
      case 'treats_low':
      case 'treats_loaded':
      case 'treats_empty':
      // treat_counter_ack: reply to treat_counter_set/reset carrying the
      // authoritative counter fields — apply immediately instead of waiting
      // for the next telemetry cycle. NOTE: reset acks report real values;
      // do not assume zero remaining from a reset.
      case 'treat_counter_ack':
        _applyTreatCounterFields(event.data, event.type);
        break;

      case 'reward':
        // Reward event (e.g. treat_dispensed): {subtype, treats_remaining, treats_low}
        if (event.data['subtype'] == 'treat_dispensed') {
          _applyTreatCounterFields(event.data, event.type);
          if (event.data['treats_remaining'] != null ||
              event.data['treats_given'] != null ||
              event.data['remaining'] != null) {
            state = state.copyWith(lastTreatTime: DateTime.now());
          }
        }
        break;

      case 'treat_dispensed':
        // Relay-forwarded dispense (robot main_treatbot → relay → app). The
        // count rides as `remaining`; applying it here moves the chip the
        // instant the treat drops instead of on the next 5s status frame.
        _applyTreatCounterFields(event.data, event.type);
        if (event.data['remaining'] != null) {
          state = state.copyWith(lastTreatTime: DateTime.now());
        }
        break;

      case 'battery':
        // Battery update - {'level': 95, 'charging': true, 'voltage': 16.6, 'temperature': 73.25, 'treats_remaining': 8, 'mode': 'idle'}
        final level = (event.data['level'] as num?)?.toDouble();
        final charging = event.data['charging'] as bool?;
        final temp = (event.data['temperature'] as num?)?.toDouble();
        final treats = asLenientInt(event.data['treats_remaining']);
        final mode = event.data['mode'] as String?;
        print('BATTERY EVENT RECEIVED: level=$level, charging=$charging, temp=$temp, treats=$treats, mode=$mode');
        _applyTreatCounterFields(event.data, event.type);
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

  /// Copy whichever treat counter fields this payload carries into state.
  /// Robot 8e8c91c contract: treats_given counts up, treats_remaining is
  /// derived server-side. treats_loaded is a deprecated alias of
  /// treats_remaining — accepted as a fallback only (pre-8e8c91c firmware).
  ///
  /// B160 (2026-09-04): `treats_remaining` is the ONE value the UI renders.
  /// Not every frame carries both fields — periodic status/battery frames
  /// carry treats_remaining, while treat_counter_ack / treats_* carry
  /// treats_given — so the display must follow whichever field the latest
  /// frame has. A given-only frame derives remaining against the hard
  /// [kTreatCapacity]; a remaining-only frame leaves given untouched (it
  /// can't be derived after a partial load). `treat_capacity` is ignored:
  /// the carousel is physically 44 slots.
  void _applyTreatCounterFields(Map<String, dynamic> data, String source) {
    final given = asLenientInt(data['treats_given']);
    // `remaining` is the key on the robot's treat_dispensed event (and the
    // legacy 'treat' event); treats_loaded is the pre-8e8c91c alias.
    final remaining = asLenientInt(data['treats_remaining']) ??
        asLenientInt(data['remaining']) ??
        asLenientInt(data['treats_loaded']);
    if (given == null && remaining == null) return;
    final nextRemaining = remaining ?? (kTreatCapacity - given!);
    final nextGiven = given ?? state.treatsGiven;
    if (nextRemaining == state.treatsRemaining &&
        nextGiven == state.treatsGiven) {
      return;
    }
    // Visible in Settings → Connection Diagnostics; only on change, so the
    // 2s status cadence doesn't flood the trace. [[debug-via-in-app-diagnostics]]
    connTrace('treats',
        'src=$source remaining=$nextRemaining given=$nextGiven'
        '${remaining == null ? ' (derived from given)' : ''}');
    state = state.copyWith(
      treatsGiven: nextGiven,
      treatsRemaining: nextRemaining,
    );
  }

  /// Extract telemetry data from any event - robot sends it in various formats
  /// Build 44: Fixed - removed overly aggressive > 0 checks that broke battery display
  void _extractBatteryFromAnyEvent(Map<String, dynamic> data) {
    // Format 1: {'level': 96, 'charging': true, 'voltage': 16.6, 'temperature': 73.25, 'treats_remaining': 8}
    if (data.containsKey('level')) {
      final level = (data['level'] as num?)?.toDouble();
      final charging = data['charging'] as bool?;
      final temp = (data['temperature'] as num?)?.toDouble();
      final treats = asLenientInt(data['treats_remaining']);
      _applyTreatCounterFields(data, 'battery-flat');
      if (level != null) {
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
      final treats = asLenientInt(batteryData['treats_remaining']);
      if (level != null) {
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
    if (batteryData is num) {
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

/// Provider for the full latest detection (includes dogName, arucoId from WS)
final lastDetectionProvider = StateProvider<Detection>((ref) {
  return const Detection();
});

/// C5: Per-dog detection map. Keyed by [Detection.trackKey] (dog_id when
/// available, falling back to aruco id or "anon"). Entries older than
/// [_detectionStaleAfter] are pruned automatically so the UI doesn't render
/// ghost boxes once a dog leaves the frame.
final allDetectionsProvider = StateNotifierProvider<AllDetectionsNotifier,
    Map<String, Detection>>((ref) {
  return AllDetectionsNotifier();
});

const Duration _detectionStaleAfter = Duration(seconds: 2);

class AllDetectionsNotifier extends StateNotifier<Map<String, Detection>> {
  AllDetectionsNotifier() : super(const {}) {
    _prunerTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _prune());
  }

  Timer? _prunerTimer;

  void upsert(Detection d) {
    if (!d.detected) return;
    final next = Map<String, Detection>.from(state);
    next[d.trackKey] = d;
    state = next;
  }

  void _prune() {
    if (state.isEmpty) return;
    final now = DateTime.now();
    final next = <String, Detection>{};
    for (final entry in state.entries) {
      final ts = entry.value.timestamp ?? now;
      if (now.difference(ts) <= _detectionStaleAfter) {
        next[entry.key] = entry.value;
      }
    }
    if (next.length != state.length) state = next;
  }

  @override
  void dispose() {
    _prunerTimer?.cancel();
    super.dispose();
  }
}

/// Provider for latest detection data (derived from telemetry for backward compat)
final detectionProvider = Provider<Detection>((ref) {
  // Prefer the full detection from WS events (has dogName/arucoId)
  final wsDetection = ref.watch(lastDetectionProvider);
  if (wsDetection.detected) return wsDetection;

  // Fallback to telemetry-derived detection
  final telemetry = ref.watch(telemetryProvider);
  return Detection(
    detected: telemetry.dogDetected,
    behavior: telemetry.currentBehavior,
    confidence: telemetry.confidence,
    timestamp: DateTime.now(),
  );
});

/// Provider that emits a Detection when an unknown dog is detected
/// (has arucoId but no matching profile). Returns null otherwise.
final unknownDogProvider = Provider<Detection?>((ref) {
  final detection = ref.watch(detectionProvider);
  if (!detection.detected || detection.arucoId == null) return null;

  final profiles = ref.watch(dogProfilesProvider);
  final matched = profiles.any((p) => p.arucoMarkerId == detection.arucoId);
  if (matched) return null;

  return detection; // Unknown dog with ArUco marker
});

/// Provider for battery level
final batteryProvider = Provider<double>((ref) {
  return ref.watch(telemetryProvider).battery;
});

/// Provider for current mode
final modeProvider = Provider<String>((ref) {
  return ref.watch(telemetryProvider).mode;
});

/// Provider for treats remaining count — the single figure the UI renders
/// (chip "X/44", sheet, Settings tile). Returns null if the robot has never
/// sent (or let us derive) the field — show "—" in UI. Clamped to
/// [0, kTreatCapacity]: pre-8e8c91c firmware could send a raw negative, and a
/// robot whose capacity drifted above 44 must not render "50/44".
final treatsRemainingProvider = Provider<int?>((ref) {
  final t = ref.watch(telemetryProvider);
  final raw = t.treatsRemaining;
  if (raw == kTreatCountUnknown) return null;
  if (raw < 0) return 0;
  return raw > kTreatCapacity ? kTreatCapacity : raw;
});
