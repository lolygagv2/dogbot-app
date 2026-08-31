import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry.freezed.dart';
part 'telemetry.g.dart';

/// Sentinel for "treat counter field never received". Robot commit 8e8c91c
/// (2026-08-30) inverted the metric: treats_given counts UP from zero (IR
/// beam-confirmed), treats_remaining is derived max(0, capacity - given) and
/// can no longer go negative. Older firmware can still send raw negatives —
/// treatsRemainingProvider clamps them; never render a negative.
const int kTreatCountUnknown = -9999;

/// Robot's default carousel capacity (one treat per slot).
const int kDefaultTreatCapacity = 44;

/// Robot telemetry/status data from /telemetry endpoint
@freezed
class Telemetry with _$Telemetry {
  const factory Telemetry({
    @Default(0.0) double battery,
    @Default(0.0) double temperature,
    @Default('') String mode,
    @Default(false) bool dogDetected,
    String? currentBehavior,
    double? confidence,
    @Default(false) bool isCharging,
    @Default(kTreatCountUnknown) int treatsRemaining, // kTreatCountUnknown = not yet received
    @Default(kTreatCountUnknown) int treatsGiven, // counts up since last load/reset; read-only from robot
    @Default(kTreatCountUnknown) int treatCapacity, // carousel size, user-settable (robot default 44)
    DateTime? lastTreatTime,
    String? activeMissionId,
    String? connectionType, // "LAN" (P2P), "WAN" (TURN relay), or null
    String? swVersion, // OTA contract: robot's running release version; null until robot slice ships
    int? volume, // System audio volume 0-100; null if unavailable this cycle
    @Default({}) Map<String, dynamic> rawData,
  }) = _Telemetry;

  factory Telemetry.fromJson(Map<String, dynamic> json) =>
      _$TelemetryFromJson(json);

  /// Create from API response which may have nested structure
  factory Telemetry.fromApiResponse(Map<String, dynamic> json) {
    // Handle battery in multiple formats:
    // 1. Top-level number: {'battery': 95}
    // 2. Nested object: {'battery': {'level': 95, 'charging': true}}
    // 3. Top-level level key: {'level': 95, 'charging': true} (from battery events)
    double batteryLevel = 0.0;
    bool isCharging = false;

    // Format 3: Top-level 'level' key (battery event format)
    if (json.containsKey('level')) {
      batteryLevel = (json['level'] as num?)?.toDouble() ?? 0.0;
      isCharging = json['charging'] as bool? ?? false;
    } else {
      // Format 1 & 2: Check 'battery' key
      final batteryData = json['battery'];
      if (batteryData is num) {
        batteryLevel = batteryData.toDouble();
      } else if (batteryData is Map) {
        batteryLevel = (batteryData['level'] as num?)?.toDouble() ?? 0.0;
        isCharging = batteryData['charging'] as bool? ?? false;
      }
    }
    // Also check top-level charging flag
    isCharging = isCharging || (json['is_charging'] as bool? ?? json['charging'] as bool? ?? false);

    return Telemetry(
      battery: batteryLevel,
      temperature: (json['temperature'] as num?)?.toDouble() ??
          (json['temp'] as num?)?.toDouble() ??
          0.0,
      mode: json['mode'] as String? ?? '',
      dogDetected: json['dog_detected'] as bool? ??
          json['dogDetected'] as bool? ??
          false,
      currentBehavior:
          json['current_behavior'] as String? ?? json['behavior'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isCharging: isCharging,
      treatsRemaining: json['treats_remaining'] as int? ??
          json['treatsRemaining'] as int? ??
          kTreatCountUnknown, // field missing from this event
      treatsGiven: json['treats_given'] as int? ?? kTreatCountUnknown,
      treatCapacity: json['treat_capacity'] as int? ?? kTreatCountUnknown,
      activeMissionId: json['active_mission_id'] as String? ??
          json['activeMission'] as String?,
      connectionType: json['connection_type'] as String?,
      swVersion: json['sw_version'] as String?,
      volume: (json['volume'] as num?)?.toInt(),
      rawData: json,
    );
  }
}

/// Dog detection event data from WebSocket
@freezed
class Detection with _$Detection {
  const factory Detection({
    @Default(false) bool detected,
    String? behavior,
    double? confidence,
    List<double>? bbox, // [x, y, width, height]
    String? dogName, // from ArUco marker identification
    int? arucoId, // ArUco marker ID if identified
    // C1/C5: stable profile id per Workstream C. Null when robot has no
    // identification (no ArUco visible AND no in-session match).
    String? dogId,
    DateTime? timestamp,
  }) = _Detection;

  factory Detection.fromJson(Map<String, dynamic> json) =>
      _$DetectionFromJson(json);

  factory Detection.fromWsEvent(Map<String, dynamic> data) {
    return Detection(
      detected: data['detected'] as bool? ?? false,
      behavior: data['behavior'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble(),
      bbox: (data['bbox'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      dogName: data['dog_name'] as String? ?? data['dogName'] as String?,
      arucoId: data['aruco_id'] as int? ?? data['arucoId'] as int?,
      dogId: data['dog_id'] as String? ?? data['dogId'] as String?,
      timestamp: DateTime.now(),
    );
  }

  /// Display name: from detection data, fallback to "Dog Detected" or "Unknown Dog"
  const Detection._();
  String get displayName {
    if (dogName != null && dogName!.isNotEmpty) return dogName!;
    if (detected) return 'Dog Detected';
    return '';
  }

  /// C5: stable map key for the multi-detection provider. Prefers dogId,
  /// falls back to aruco id, then to a sentinel "anon" so unidentified dogs
  /// still get a slot.
  String get trackKey {
    if (dogId != null && dogId!.isNotEmpty) return dogId!;
    if (arucoId != null) return 'aruco_$arucoId';
    return 'anon';
  }
}
