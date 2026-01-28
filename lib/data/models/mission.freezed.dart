// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Mission _$MissionFromJson(Map<String, dynamic> json) {
  return _Mission.fromJson(json);
}

/// @nodoc
mixin _$Mission {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get targetBehavior => throw _privateConstructorUsedError;
  double get requiredDuration => throw _privateConstructorUsedError;
  int get cooldownSeconds => throw _privateConstructorUsedError;
  int get dailyLimit => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  int get rewardsGiven => throw _privateConstructorUsedError;
  double get progress => throw _privateConstructorUsedError;

  /// Serializes this Mission to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Mission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MissionCopyWith<Mission> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissionCopyWith<$Res> {
  factory $MissionCopyWith(Mission value, $Res Function(Mission) then) =
      _$MissionCopyWithImpl<$Res, Mission>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String targetBehavior,
      double requiredDuration,
      int cooldownSeconds,
      int dailyLimit,
      bool isActive,
      int rewardsGiven,
      double progress});
}

/// @nodoc
class _$MissionCopyWithImpl<$Res, $Val extends Mission>
    implements $MissionCopyWith<$Res> {
  _$MissionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Mission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? targetBehavior = null,
    Object? requiredDuration = null,
    Object? cooldownSeconds = null,
    Object? dailyLimit = null,
    Object? isActive = null,
    Object? rewardsGiven = null,
    Object? progress = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      targetBehavior: null == targetBehavior
          ? _value.targetBehavior
          : targetBehavior // ignore: cast_nullable_to_non_nullable
              as String,
      requiredDuration: null == requiredDuration
          ? _value.requiredDuration
          : requiredDuration // ignore: cast_nullable_to_non_nullable
              as double,
      cooldownSeconds: null == cooldownSeconds
          ? _value.cooldownSeconds
          : cooldownSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      dailyLimit: null == dailyLimit
          ? _value.dailyLimit
          : dailyLimit // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      rewardsGiven: null == rewardsGiven
          ? _value.rewardsGiven
          : rewardsGiven // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MissionImplCopyWith<$Res> implements $MissionCopyWith<$Res> {
  factory _$$MissionImplCopyWith(
          _$MissionImpl value, $Res Function(_$MissionImpl) then) =
      __$$MissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String targetBehavior,
      double requiredDuration,
      int cooldownSeconds,
      int dailyLimit,
      bool isActive,
      int rewardsGiven,
      double progress});
}

/// @nodoc
class __$$MissionImplCopyWithImpl<$Res>
    extends _$MissionCopyWithImpl<$Res, _$MissionImpl>
    implements _$$MissionImplCopyWith<$Res> {
  __$$MissionImplCopyWithImpl(
      _$MissionImpl _value, $Res Function(_$MissionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Mission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? targetBehavior = null,
    Object? requiredDuration = null,
    Object? cooldownSeconds = null,
    Object? dailyLimit = null,
    Object? isActive = null,
    Object? rewardsGiven = null,
    Object? progress = null,
  }) {
    return _then(_$MissionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      targetBehavior: null == targetBehavior
          ? _value.targetBehavior
          : targetBehavior // ignore: cast_nullable_to_non_nullable
              as String,
      requiredDuration: null == requiredDuration
          ? _value.requiredDuration
          : requiredDuration // ignore: cast_nullable_to_non_nullable
              as double,
      cooldownSeconds: null == cooldownSeconds
          ? _value.cooldownSeconds
          : cooldownSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      dailyLimit: null == dailyLimit
          ? _value.dailyLimit
          : dailyLimit // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      rewardsGiven: null == rewardsGiven
          ? _value.rewardsGiven
          : rewardsGiven // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MissionImpl implements _Mission {
  const _$MissionImpl(
      {required this.id,
      required this.name,
      this.description,
      this.targetBehavior = 'sit',
      this.requiredDuration = 3.0,
      this.cooldownSeconds = 15,
      this.dailyLimit = 10,
      this.isActive = false,
      this.rewardsGiven = 0,
      this.progress = 0.0});

  factory _$MissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$MissionImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey()
  final String targetBehavior;
  @override
  @JsonKey()
  final double requiredDuration;
  @override
  @JsonKey()
  final int cooldownSeconds;
  @override
  @JsonKey()
  final int dailyLimit;
  @override
  @JsonKey()
  final bool isActive;
  @override
  @JsonKey()
  final int rewardsGiven;
  @override
  @JsonKey()
  final double progress;

  @override
  String toString() {
    return 'Mission(id: $id, name: $name, description: $description, targetBehavior: $targetBehavior, requiredDuration: $requiredDuration, cooldownSeconds: $cooldownSeconds, dailyLimit: $dailyLimit, isActive: $isActive, rewardsGiven: $rewardsGiven, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.targetBehavior, targetBehavior) ||
                other.targetBehavior == targetBehavior) &&
            (identical(other.requiredDuration, requiredDuration) ||
                other.requiredDuration == requiredDuration) &&
            (identical(other.cooldownSeconds, cooldownSeconds) ||
                other.cooldownSeconds == cooldownSeconds) &&
            (identical(other.dailyLimit, dailyLimit) ||
                other.dailyLimit == dailyLimit) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.rewardsGiven, rewardsGiven) ||
                other.rewardsGiven == rewardsGiven) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      targetBehavior,
      requiredDuration,
      cooldownSeconds,
      dailyLimit,
      isActive,
      rewardsGiven,
      progress);

  /// Create a copy of Mission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MissionImplCopyWith<_$MissionImpl> get copyWith =>
      __$$MissionImplCopyWithImpl<_$MissionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MissionImplToJson(
      this,
    );
  }
}

abstract class _Mission implements Mission {
  const factory _Mission(
      {required final String id,
      required final String name,
      final String? description,
      final String targetBehavior,
      final double requiredDuration,
      final int cooldownSeconds,
      final int dailyLimit,
      final bool isActive,
      final int rewardsGiven,
      final double progress}) = _$MissionImpl;

  factory _Mission.fromJson(Map<String, dynamic> json) = _$MissionImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String get targetBehavior;
  @override
  double get requiredDuration;
  @override
  int get cooldownSeconds;
  @override
  int get dailyLimit;
  @override
  bool get isActive;
  @override
  int get rewardsGiven;
  @override
  double get progress;

  /// Create a copy of Mission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MissionImplCopyWith<_$MissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MissionProgress _$MissionProgressFromJson(Map<String, dynamic> json) {
  return _MissionProgress.fromJson(json);
}

/// @nodoc
mixin _$MissionProgress {
  String get missionId => throw _privateConstructorUsedError;
  double get progress => throw _privateConstructorUsedError;
  int get rewardsGiven => throw _privateConstructorUsedError;
  int get successCount => throw _privateConstructorUsedError;
  int get failCount => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  String? get stage => throw _privateConstructorUsedError;
  String? get trick => throw _privateConstructorUsedError;
  double? get targetSec => throw _privateConstructorUsedError;
  double? get holdTime => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;

  /// Serializes this MissionProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MissionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MissionProgressCopyWith<MissionProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissionProgressCopyWith<$Res> {
  factory $MissionProgressCopyWith(
          MissionProgress value, $Res Function(MissionProgress) then) =
      _$MissionProgressCopyWithImpl<$Res, MissionProgress>;
  @useResult
  $Res call(
      {String missionId,
      double progress,
      int rewardsGiven,
      int successCount,
      int failCount,
      String? status,
      DateTime? startedAt,
      String? stage,
      String? trick,
      double? targetSec,
      double? holdTime,
      String? reason});
}

/// @nodoc
class _$MissionProgressCopyWithImpl<$Res, $Val extends MissionProgress>
    implements $MissionProgressCopyWith<$Res> {
  _$MissionProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MissionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? missionId = null,
    Object? progress = null,
    Object? rewardsGiven = null,
    Object? successCount = null,
    Object? failCount = null,
    Object? status = freezed,
    Object? startedAt = freezed,
    Object? stage = freezed,
    Object? trick = freezed,
    Object? targetSec = freezed,
    Object? holdTime = freezed,
    Object? reason = freezed,
  }) {
    return _then(_value.copyWith(
      missionId: null == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
      rewardsGiven: null == rewardsGiven
          ? _value.rewardsGiven
          : rewardsGiven // ignore: cast_nullable_to_non_nullable
              as int,
      successCount: null == successCount
          ? _value.successCount
          : successCount // ignore: cast_nullable_to_non_nullable
              as int,
      failCount: null == failCount
          ? _value.failCount
          : failCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      stage: freezed == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as String?,
      trick: freezed == trick
          ? _value.trick
          : trick // ignore: cast_nullable_to_non_nullable
              as String?,
      targetSec: freezed == targetSec
          ? _value.targetSec
          : targetSec // ignore: cast_nullable_to_non_nullable
              as double?,
      holdTime: freezed == holdTime
          ? _value.holdTime
          : holdTime // ignore: cast_nullable_to_non_nullable
              as double?,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MissionProgressImplCopyWith<$Res>
    implements $MissionProgressCopyWith<$Res> {
  factory _$$MissionProgressImplCopyWith(_$MissionProgressImpl value,
          $Res Function(_$MissionProgressImpl) then) =
      __$$MissionProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String missionId,
      double progress,
      int rewardsGiven,
      int successCount,
      int failCount,
      String? status,
      DateTime? startedAt,
      String? stage,
      String? trick,
      double? targetSec,
      double? holdTime,
      String? reason});
}

/// @nodoc
class __$$MissionProgressImplCopyWithImpl<$Res>
    extends _$MissionProgressCopyWithImpl<$Res, _$MissionProgressImpl>
    implements _$$MissionProgressImplCopyWith<$Res> {
  __$$MissionProgressImplCopyWithImpl(
      _$MissionProgressImpl _value, $Res Function(_$MissionProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of MissionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? missionId = null,
    Object? progress = null,
    Object? rewardsGiven = null,
    Object? successCount = null,
    Object? failCount = null,
    Object? status = freezed,
    Object? startedAt = freezed,
    Object? stage = freezed,
    Object? trick = freezed,
    Object? targetSec = freezed,
    Object? holdTime = freezed,
    Object? reason = freezed,
  }) {
    return _then(_$MissionProgressImpl(
      missionId: null == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
      rewardsGiven: null == rewardsGiven
          ? _value.rewardsGiven
          : rewardsGiven // ignore: cast_nullable_to_non_nullable
              as int,
      successCount: null == successCount
          ? _value.successCount
          : successCount // ignore: cast_nullable_to_non_nullable
              as int,
      failCount: null == failCount
          ? _value.failCount
          : failCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      stage: freezed == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as String?,
      trick: freezed == trick
          ? _value.trick
          : trick // ignore: cast_nullable_to_non_nullable
              as String?,
      targetSec: freezed == targetSec
          ? _value.targetSec
          : targetSec // ignore: cast_nullable_to_non_nullable
              as double?,
      holdTime: freezed == holdTime
          ? _value.holdTime
          : holdTime // ignore: cast_nullable_to_non_nullable
              as double?,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MissionProgressImpl extends _MissionProgress {
  const _$MissionProgressImpl(
      {required this.missionId,
      this.progress = 0.0,
      this.rewardsGiven = 0,
      this.successCount = 0,
      this.failCount = 0,
      this.status,
      this.startedAt,
      this.stage,
      this.trick,
      this.targetSec,
      this.holdTime,
      this.reason})
      : super._();

  factory _$MissionProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$MissionProgressImplFromJson(json);

  @override
  final String missionId;
  @override
  @JsonKey()
  final double progress;
  @override
  @JsonKey()
  final int rewardsGiven;
  @override
  @JsonKey()
  final int successCount;
  @override
  @JsonKey()
  final int failCount;
  @override
  final String? status;
  @override
  final DateTime? startedAt;
  @override
  final String? stage;
  @override
  final String? trick;
  @override
  final double? targetSec;
  @override
  final double? holdTime;
  @override
  final String? reason;

  @override
  String toString() {
    return 'MissionProgress(missionId: $missionId, progress: $progress, rewardsGiven: $rewardsGiven, successCount: $successCount, failCount: $failCount, status: $status, startedAt: $startedAt, stage: $stage, trick: $trick, targetSec: $targetSec, holdTime: $holdTime, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissionProgressImpl &&
            (identical(other.missionId, missionId) ||
                other.missionId == missionId) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.rewardsGiven, rewardsGiven) ||
                other.rewardsGiven == rewardsGiven) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failCount, failCount) ||
                other.failCount == failCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.trick, trick) || other.trick == trick) &&
            (identical(other.targetSec, targetSec) ||
                other.targetSec == targetSec) &&
            (identical(other.holdTime, holdTime) ||
                other.holdTime == holdTime) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      missionId,
      progress,
      rewardsGiven,
      successCount,
      failCount,
      status,
      startedAt,
      stage,
      trick,
      targetSec,
      holdTime,
      reason);

  /// Create a copy of MissionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MissionProgressImplCopyWith<_$MissionProgressImpl> get copyWith =>
      __$$MissionProgressImplCopyWithImpl<_$MissionProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MissionProgressImplToJson(
      this,
    );
  }
}

abstract class _MissionProgress extends MissionProgress {
  const factory _MissionProgress(
      {required final String missionId,
      final double progress,
      final int rewardsGiven,
      final int successCount,
      final int failCount,
      final String? status,
      final DateTime? startedAt,
      final String? stage,
      final String? trick,
      final double? targetSec,
      final double? holdTime,
      final String? reason}) = _$MissionProgressImpl;
  const _MissionProgress._() : super._();

  factory _MissionProgress.fromJson(Map<String, dynamic> json) =
      _$MissionProgressImpl.fromJson;

  @override
  String get missionId;
  @override
  double get progress;
  @override
  int get rewardsGiven;
  @override
  int get successCount;
  @override
  int get failCount;
  @override
  String? get status;
  @override
  DateTime? get startedAt;
  @override
  String? get stage;
  @override
  String? get trick;
  @override
  double? get targetSec;
  @override
  double? get holdTime;
  @override
  String? get reason;

  /// Create a copy of MissionProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MissionProgressImplCopyWith<_$MissionProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
