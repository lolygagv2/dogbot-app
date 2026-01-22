import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry.freezed.dart';
part 'telemetry.g.dart';

/// Robot telemetry/status data from /telemetry endpoint
@freezed
class Telemetry with _$Telemetry {
  const factory Telemetry({
    @Default(0.0) double battery,
    @Default(0.0) double temperature,
    @Default('idle') String mode,
    @Default(false) bool dogDetected,
    String? currentBehavior,
    double? confidence,
    @Default(false) bool isCharging,
    @Default(0) int treatsRemaining,
    DateTime? lastTreatTime,
    String? activeMissionId,
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
      mode: json['mode'] as String? ?? 'idle',
      dogDetected: json['dog_detected'] as bool? ??
          json['dogDetected'] as bool? ??
          false,
      currentBehavior:
          json['current_behavior'] as String? ?? json['behavior'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isCharging: isCharging,
      treatsRemaining: json['treats_remaining'] as int? ??
          json['treatsRemaining'] as int? ??
          0,
      activeMissionId: json['active_mission_id'] as String? ??
          json['activeMission'] as String?,
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
      timestamp: DateTime.now(),
    );
  }
}
