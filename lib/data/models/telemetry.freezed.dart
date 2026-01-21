// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telemetry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Telemetry _$TelemetryFromJson(Map<String, dynamic> json) {
  return _Telemetry.fromJson(json);
}

/// @nodoc
mixin _$Telemetry {
  double get battery => throw _privateConstructorUsedError;
  double get temperature => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  bool get dogDetected => throw _privateConstructorUsedError;
  String? get currentBehavior => throw _privateConstructorUsedError;
  double? get confidence => throw _privateConstructorUsedError;
  bool get isCharging => throw _privateConstructorUsedError;
  int get treatsRemaining => throw _privateConstructorUsedError;
  DateTime? get lastTreatTime => throw _privateConstructorUsedError;
  String? get activeMissionId => throw _privateConstructorUsedError;
  Map<String, dynamic> get rawData => throw _privateConstructorUsedError;

  /// Serializes this Telemetry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Telemetry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TelemetryCopyWith<Telemetry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TelemetryCopyWith<$Res> {
  factory $TelemetryCopyWith(Telemetry value, $Res Function(Telemetry) then) =
      _$TelemetryCopyWithImpl<$Res, Telemetry>;
  @useResult
  $Res call(
      {double battery,
      double temperature,
      String mode,
      bool dogDetected,
      String? currentBehavior,
      double? confidence,
      bool isCharging,
      int treatsRemaining,
      DateTime? lastTreatTime,
      String? activeMissionId,
      Map<String, dynamic> rawData});
}

/// @nodoc
class _$TelemetryCopyWithImpl<$Res, $Val extends Telemetry>
    implements $TelemetryCopyWith<$Res> {
  _$TelemetryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Telemetry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? battery = null,
    Object? temperature = null,
    Object? mode = null,
    Object? dogDetected = null,
    Object? currentBehavior = freezed,
    Object? confidence = freezed,
    Object? isCharging = null,
    Object? treatsRemaining = null,
    Object? lastTreatTime = freezed,
    Object? activeMissionId = freezed,
    Object? rawData = null,
  }) {
    return _then(_value.copyWith(
      battery: null == battery
          ? _value.battery
          : battery // ignore: cast_nullable_to_non_nullable
              as double,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      dogDetected: null == dogDetected
          ? _value.dogDetected
          : dogDetected // ignore: cast_nullable_to_non_nullable
              as bool,
      currentBehavior: freezed == currentBehavior
          ? _value.currentBehavior
          : currentBehavior // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
      isCharging: null == isCharging
          ? _value.isCharging
          : isCharging // ignore: cast_nullable_to_non_nullable
              as bool,
      treatsRemaining: null == treatsRemaining
          ? _value.treatsRemaining
          : treatsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
      lastTreatTime: freezed == lastTreatTime
          ? _value.lastTreatTime
          : lastTreatTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeMissionId: freezed == activeMissionId
          ? _value.activeMissionId
          : activeMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      rawData: null == rawData
          ? _value.rawData
          : rawData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TelemetryImplCopyWith<$Res>
    implements $TelemetryCopyWith<$Res> {
  factory _$$TelemetryImplCopyWith(
          _$TelemetryImpl value, $Res Function(_$TelemetryImpl) then) =
      __$$TelemetryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double battery,
      double temperature,
      String mode,
      bool dogDetected,
      String? currentBehavior,
      double? confidence,
      bool isCharging,
      int treatsRemaining,
      DateTime? lastTreatTime,
      String? activeMissionId,
      Map<String, dynamic> rawData});
}

/// @nodoc
class __$$TelemetryImplCopyWithImpl<$Res>
    extends _$TelemetryCopyWithImpl<$Res, _$TelemetryImpl>
    implements _$$TelemetryImplCopyWith<$Res> {
  __$$TelemetryImplCopyWithImpl(
      _$TelemetryImpl _value, $Res Function(_$TelemetryImpl) _then)
      : super(_value, _then);

  /// Create a copy of Telemetry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? battery = null,
    Object? temperature = null,
    Object? mode = null,
    Object? dogDetected = null,
    Object? currentBehavior = freezed,
    Object? confidence = freezed,
    Object? isCharging = null,
    Object? treatsRemaining = null,
    Object? lastTreatTime = freezed,
    Object? activeMissionId = freezed,
    Object? rawData = null,
  }) {
    return _then(_$TelemetryImpl(
      battery: null == battery
          ? _value.battery
          : battery // ignore: cast_nullable_to_non_nullable
              as double,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      dogDetected: null == dogDetected
          ? _value.dogDetected
          : dogDetected // ignore: cast_nullable_to_non_nullable
              as bool,
      currentBehavior: freezed == currentBehavior
          ? _value.currentBehavior
          : currentBehavior // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
      isCharging: null == isCharging
          ? _value.isCharging
          : isCharging // ignore: cast_nullable_to_non_nullable
              as bool,
      treatsRemaining: null == treatsRemaining
          ? _value.treatsRemaining
          : treatsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
      lastTreatTime: freezed == lastTreatTime
          ? _value.lastTreatTime
          : lastTreatTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeMissionId: freezed == activeMissionId
          ? _value.activeMissionId
          : activeMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      rawData: null == rawData
          ? _value._rawData
          : rawData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TelemetryImpl implements _Telemetry {
  const _$TelemetryImpl(
      {this.battery = 0.0,
      this.temperature = 0.0,
      this.mode = 'idle',
      this.dogDetected = false,
      this.currentBehavior,
      this.confidence,
      this.isCharging = false,
      this.treatsRemaining = 0,
      this.lastTreatTime,
      this.activeMissionId,
      final Map<String, dynamic> rawData = const {}})
      : _rawData = rawData;

  factory _$TelemetryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TelemetryImplFromJson(json);

  @override
  @JsonKey()
  final double battery;
  @override
  @JsonKey()
  final double temperature;
  @override
  @JsonKey()
  final String mode;
  @override
  @JsonKey()
  final bool dogDetected;
  @override
  final String? currentBehavior;
  @override
  final double? confidence;
  @override
  @JsonKey()
  final bool isCharging;
  @override
  @JsonKey()
  final int treatsRemaining;
  @override
  final DateTime? lastTreatTime;
  @override
  final String? activeMissionId;
  final Map<String, dynamic> _rawData;
  @override
  @JsonKey()
  Map<String, dynamic> get rawData {
    if (_rawData is EqualUnmodifiableMapView) return _rawData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_rawData);
  }

  @override
  String toString() {
    return 'Telemetry(battery: $battery, temperature: $temperature, mode: $mode, dogDetected: $dogDetected, currentBehavior: $currentBehavior, confidence: $confidence, isCharging: $isCharging, treatsRemaining: $treatsRemaining, lastTreatTime: $lastTreatTime, activeMissionId: $activeMissionId, rawData: $rawData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TelemetryImpl &&
            (identical(other.battery, battery) || other.battery == battery) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.dogDetected, dogDetected) ||
                other.dogDetected == dogDetected) &&
            (identical(other.currentBehavior, currentBehavior) ||
                other.currentBehavior == currentBehavior) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.isCharging, isCharging) ||
                other.isCharging == isCharging) &&
            (identical(other.treatsRemaining, treatsRemaining) ||
                other.treatsRemaining == treatsRemaining) &&
            (identical(other.lastTreatTime, lastTreatTime) ||
                other.lastTreatTime == lastTreatTime) &&
            (identical(other.activeMissionId, activeMissionId) ||
                other.activeMissionId == activeMissionId) &&
            const DeepCollectionEquality().equals(other._rawData, _rawData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      battery,
      temperature,
      mode,
      dogDetected,
      currentBehavior,
      confidence,
      isCharging,
      treatsRemaining,
      lastTreatTime,
      activeMissionId,
      const DeepCollectionEquality().hash(_rawData));

  /// Create a copy of Telemetry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TelemetryImplCopyWith<_$TelemetryImpl> get copyWith =>
      __$$TelemetryImplCopyWithImpl<_$TelemetryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TelemetryImplToJson(
      this,
    );
  }
}

abstract class _Telemetry implements Telemetry {
  const factory _Telemetry(
      {final double battery,
      final double temperature,
      final String mode,
      final bool dogDetected,
      final String? currentBehavior,
      final double? confidence,
      final bool isCharging,
      final int treatsRemaining,
      final DateTime? lastTreatTime,
      final String? activeMissionId,
      final Map<String, dynamic> rawData}) = _$TelemetryImpl;

  factory _Telemetry.fromJson(Map<String, dynamic> json) =
      _$TelemetryImpl.fromJson;

  @override
  double get battery;
  @override
  double get temperature;
  @override
  String get mode;
  @override
  bool get dogDetected;
  @override
  String? get currentBehavior;
  @override
  double? get confidence;
  @override
  bool get isCharging;
  @override
  int get treatsRemaining;
  @override
  DateTime? get lastTreatTime;
  @override
  String? get activeMissionId;
  @override
  Map<String, dynamic> get rawData;

  /// Create a copy of Telemetry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TelemetryImplCopyWith<_$TelemetryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Detection _$DetectionFromJson(Map<String, dynamic> json) {
  return _Detection.fromJson(json);
}

/// @nodoc
mixin _$Detection {
  bool get detected => throw _privateConstructorUsedError;
  String? get behavior => throw _privateConstructorUsedError;
  double? get confidence => throw _privateConstructorUsedError;
  List<double>? get bbox =>
      throw _privateConstructorUsedError; // [x, y, width, height]
  DateTime? get timestamp => throw _privateConstructorUsedError;

  /// Serializes this Detection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Detection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DetectionCopyWith<Detection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DetectionCopyWith<$Res> {
  factory $DetectionCopyWith(Detection value, $Res Function(Detection) then) =
      _$DetectionCopyWithImpl<$Res, Detection>;
  @useResult
  $Res call(
      {bool detected,
      String? behavior,
      double? confidence,
      List<double>? bbox,
      DateTime? timestamp});
}

/// @nodoc
class _$DetectionCopyWithImpl<$Res, $Val extends Detection>
    implements $DetectionCopyWith<$Res> {
  _$DetectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Detection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? detected = null,
    Object? behavior = freezed,
    Object? confidence = freezed,
    Object? bbox = freezed,
    Object? timestamp = freezed,
  }) {
    return _then(_value.copyWith(
      detected: null == detected
          ? _value.detected
          : detected // ignore: cast_nullable_to_non_nullable
              as bool,
      behavior: freezed == behavior
          ? _value.behavior
          : behavior // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
      bbox: freezed == bbox
          ? _value.bbox
          : bbox // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DetectionImplCopyWith<$Res>
    implements $DetectionCopyWith<$Res> {
  factory _$$DetectionImplCopyWith(
          _$DetectionImpl value, $Res Function(_$DetectionImpl) then) =
      __$$DetectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool detected,
      String? behavior,
      double? confidence,
      List<double>? bbox,
      DateTime? timestamp});
}

/// @nodoc
class __$$DetectionImplCopyWithImpl<$Res>
    extends _$DetectionCopyWithImpl<$Res, _$DetectionImpl>
    implements _$$DetectionImplCopyWith<$Res> {
  __$$DetectionImplCopyWithImpl(
      _$DetectionImpl _value, $Res Function(_$DetectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Detection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? detected = null,
    Object? behavior = freezed,
    Object? confidence = freezed,
    Object? bbox = freezed,
    Object? timestamp = freezed,
  }) {
    return _then(_$DetectionImpl(
      detected: null == detected
          ? _value.detected
          : detected // ignore: cast_nullable_to_non_nullable
              as bool,
      behavior: freezed == behavior
          ? _value.behavior
          : behavior // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
      bbox: freezed == bbox
          ? _value._bbox
          : bbox // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DetectionImpl implements _Detection {
  const _$DetectionImpl(
      {this.detected = false,
      this.behavior,
      this.confidence,
      final List<double>? bbox,
      this.timestamp})
      : _bbox = bbox;

  factory _$DetectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$DetectionImplFromJson(json);

  @override
  @JsonKey()
  final bool detected;
  @override
  final String? behavior;
  @override
  final double? confidence;
  final List<double>? _bbox;
  @override
  List<double>? get bbox {
    final value = _bbox;
    if (value == null) return null;
    if (_bbox is EqualUnmodifiableListView) return _bbox;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// [x, y, width, height]
  @override
  final DateTime? timestamp;

  @override
  String toString() {
    return 'Detection(detected: $detected, behavior: $behavior, confidence: $confidence, bbox: $bbox, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DetectionImpl &&
            (identical(other.detected, detected) ||
                other.detected == detected) &&
            (identical(other.behavior, behavior) ||
                other.behavior == behavior) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality().equals(other._bbox, _bbox) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, detected, behavior, confidence,
      const DeepCollectionEquality().hash(_bbox), timestamp);

  /// Create a copy of Detection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DetectionImplCopyWith<_$DetectionImpl> get copyWith =>
      __$$DetectionImplCopyWithImpl<_$DetectionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DetectionImplToJson(
      this,
    );
  }
}

abstract class _Detection implements Detection {
  const factory _Detection(
      {final bool detected,
      final String? behavior,
      final double? confidence,
      final List<double>? bbox,
      final DateTime? timestamp}) = _$DetectionImpl;

  factory _Detection.fromJson(Map<String, dynamic> json) =
      _$DetectionImpl.fromJson;

  @override
  bool get detected;
  @override
  String? get behavior;
  @override
  double? get confidence;
  @override
  List<double>? get bbox; // [x, y, width, height]
  @override
  DateTime? get timestamp;

  /// Create a copy of Detection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DetectionImplCopyWith<_$DetectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
