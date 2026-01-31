// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Program _$ProgramFromJson(Map<String, dynamic> json) {
  return _Program.fromJson(json);
}

/// @nodoc
mixin _$Program {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<String> get missionIds => throw _privateConstructorUsedError;
  int get restSecondsBetween => throw _privateConstructorUsedError;
  int get currentMissionIndex => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get iconName => throw _privateConstructorUsedError;

  /// Serializes this Program to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProgramCopyWith<Program> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProgramCopyWith<$Res> {
  factory $ProgramCopyWith(Program value, $Res Function(Program) then) =
      _$ProgramCopyWithImpl<$Res, Program>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      List<String> missionIds,
      int restSecondsBetween,
      int currentMissionIndex,
      bool isActive,
      String? iconName});
}

/// @nodoc
class _$ProgramCopyWithImpl<$Res, $Val extends Program>
    implements $ProgramCopyWith<$Res> {
  _$ProgramCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? missionIds = null,
    Object? restSecondsBetween = null,
    Object? currentMissionIndex = null,
    Object? isActive = null,
    Object? iconName = freezed,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      missionIds: null == missionIds
          ? _value.missionIds
          : missionIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      restSecondsBetween: null == restSecondsBetween
          ? _value.restSecondsBetween
          : restSecondsBetween // ignore: cast_nullable_to_non_nullable
              as int,
      currentMissionIndex: null == currentMissionIndex
          ? _value.currentMissionIndex
          : currentMissionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      iconName: freezed == iconName
          ? _value.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProgramImplCopyWith<$Res> implements $ProgramCopyWith<$Res> {
  factory _$$ProgramImplCopyWith(
          _$ProgramImpl value, $Res Function(_$ProgramImpl) then) =
      __$$ProgramImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      List<String> missionIds,
      int restSecondsBetween,
      int currentMissionIndex,
      bool isActive,
      String? iconName});
}

/// @nodoc
class __$$ProgramImplCopyWithImpl<$Res>
    extends _$ProgramCopyWithImpl<$Res, _$ProgramImpl>
    implements _$$ProgramImplCopyWith<$Res> {
  __$$ProgramImplCopyWithImpl(
      _$ProgramImpl _value, $Res Function(_$ProgramImpl) _then)
      : super(_value, _then);

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? missionIds = null,
    Object? restSecondsBetween = null,
    Object? currentMissionIndex = null,
    Object? isActive = null,
    Object? iconName = freezed,
  }) {
    return _then(_$ProgramImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      missionIds: null == missionIds
          ? _value._missionIds
          : missionIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      restSecondsBetween: null == restSecondsBetween
          ? _value.restSecondsBetween
          : restSecondsBetween // ignore: cast_nullable_to_non_nullable
              as int,
      currentMissionIndex: null == currentMissionIndex
          ? _value.currentMissionIndex
          : currentMissionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      iconName: freezed == iconName
          ? _value.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProgramImpl extends _Program {
  const _$ProgramImpl(
      {required this.id,
      required this.name,
      required this.description,
      required final List<String> missionIds,
      this.restSecondsBetween = 30,
      this.currentMissionIndex = 0,
      this.isActive = false,
      this.iconName})
      : _missionIds = missionIds,
        super._();

  factory _$ProgramImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProgramImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  final List<String> _missionIds;
  @override
  List<String> get missionIds {
    if (_missionIds is EqualUnmodifiableListView) return _missionIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_missionIds);
  }

  @override
  @JsonKey()
  final int restSecondsBetween;
  @override
  @JsonKey()
  final int currentMissionIndex;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? iconName;

  @override
  String toString() {
    return 'Program(id: $id, name: $name, description: $description, missionIds: $missionIds, restSecondsBetween: $restSecondsBetween, currentMissionIndex: $currentMissionIndex, isActive: $isActive, iconName: $iconName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProgramImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._missionIds, _missionIds) &&
            (identical(other.restSecondsBetween, restSecondsBetween) ||
                other.restSecondsBetween == restSecondsBetween) &&
            (identical(other.currentMissionIndex, currentMissionIndex) ||
                other.currentMissionIndex == currentMissionIndex) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      const DeepCollectionEquality().hash(_missionIds),
      restSecondsBetween,
      currentMissionIndex,
      isActive,
      iconName);

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProgramImplCopyWith<_$ProgramImpl> get copyWith =>
      __$$ProgramImplCopyWithImpl<_$ProgramImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProgramImplToJson(
      this,
    );
  }
}

abstract class _Program extends Program {
  const factory _Program(
      {required final String id,
      required final String name,
      required final String description,
      required final List<String> missionIds,
      final int restSecondsBetween,
      final int currentMissionIndex,
      final bool isActive,
      final String? iconName}) = _$ProgramImpl;
  const _Program._() : super._();

  factory _Program.fromJson(Map<String, dynamic> json) = _$ProgramImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  List<String> get missionIds;
  @override
  int get restSecondsBetween;
  @override
  int get currentMissionIndex;
  @override
  bool get isActive;
  @override
  String? get iconName;

  /// Create a copy of Program
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProgramImplCopyWith<_$ProgramImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ProgramProgress _$ProgramProgressFromJson(Map<String, dynamic> json) {
  return _ProgramProgress.fromJson(json);
}

/// @nodoc
mixin _$ProgramProgress {
  String get programId => throw _privateConstructorUsedError;
  int get currentMissionIndex => throw _privateConstructorUsedError;
  int get totalMissions => throw _privateConstructorUsedError;
  bool get isResting => throw _privateConstructorUsedError;
  int get restSecondsRemaining => throw _privateConstructorUsedError;
  String? get currentMissionId => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;

  /// Serializes this ProgramProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProgramProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProgramProgressCopyWith<ProgramProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProgramProgressCopyWith<$Res> {
  factory $ProgramProgressCopyWith(
          ProgramProgress value, $Res Function(ProgramProgress) then) =
      _$ProgramProgressCopyWithImpl<$Res, ProgramProgress>;
  @useResult
  $Res call(
      {String programId,
      int currentMissionIndex,
      int totalMissions,
      bool isResting,
      int restSecondsRemaining,
      String? currentMissionId,
      String? status});
}

/// @nodoc
class _$ProgramProgressCopyWithImpl<$Res, $Val extends ProgramProgress>
    implements $ProgramProgressCopyWith<$Res> {
  _$ProgramProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProgramProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? programId = null,
    Object? currentMissionIndex = null,
    Object? totalMissions = null,
    Object? isResting = null,
    Object? restSecondsRemaining = null,
    Object? currentMissionId = freezed,
    Object? status = freezed,
  }) {
    return _then(_value.copyWith(
      programId: null == programId
          ? _value.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String,
      currentMissionIndex: null == currentMissionIndex
          ? _value.currentMissionIndex
          : currentMissionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      totalMissions: null == totalMissions
          ? _value.totalMissions
          : totalMissions // ignore: cast_nullable_to_non_nullable
              as int,
      isResting: null == isResting
          ? _value.isResting
          : isResting // ignore: cast_nullable_to_non_nullable
              as bool,
      restSecondsRemaining: null == restSecondsRemaining
          ? _value.restSecondsRemaining
          : restSecondsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
      currentMissionId: freezed == currentMissionId
          ? _value.currentMissionId
          : currentMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProgramProgressImplCopyWith<$Res>
    implements $ProgramProgressCopyWith<$Res> {
  factory _$$ProgramProgressImplCopyWith(_$ProgramProgressImpl value,
          $Res Function(_$ProgramProgressImpl) then) =
      __$$ProgramProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String programId,
      int currentMissionIndex,
      int totalMissions,
      bool isResting,
      int restSecondsRemaining,
      String? currentMissionId,
      String? status});
}

/// @nodoc
class __$$ProgramProgressImplCopyWithImpl<$Res>
    extends _$ProgramProgressCopyWithImpl<$Res, _$ProgramProgressImpl>
    implements _$$ProgramProgressImplCopyWith<$Res> {
  __$$ProgramProgressImplCopyWithImpl(
      _$ProgramProgressImpl _value, $Res Function(_$ProgramProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of ProgramProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? programId = null,
    Object? currentMissionIndex = null,
    Object? totalMissions = null,
    Object? isResting = null,
    Object? restSecondsRemaining = null,
    Object? currentMissionId = freezed,
    Object? status = freezed,
  }) {
    return _then(_$ProgramProgressImpl(
      programId: null == programId
          ? _value.programId
          : programId // ignore: cast_nullable_to_non_nullable
              as String,
      currentMissionIndex: null == currentMissionIndex
          ? _value.currentMissionIndex
          : currentMissionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      totalMissions: null == totalMissions
          ? _value.totalMissions
          : totalMissions // ignore: cast_nullable_to_non_nullable
              as int,
      isResting: null == isResting
          ? _value.isResting
          : isResting // ignore: cast_nullable_to_non_nullable
              as bool,
      restSecondsRemaining: null == restSecondsRemaining
          ? _value.restSecondsRemaining
          : restSecondsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
      currentMissionId: freezed == currentMissionId
          ? _value.currentMissionId
          : currentMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProgramProgressImpl extends _ProgramProgress {
  const _$ProgramProgressImpl(
      {required this.programId,
      this.currentMissionIndex = 0,
      this.totalMissions = 0,
      this.isResting = false,
      this.restSecondsRemaining = 0,
      this.currentMissionId,
      this.status})
      : super._();

  factory _$ProgramProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProgramProgressImplFromJson(json);

  @override
  final String programId;
  @override
  @JsonKey()
  final int currentMissionIndex;
  @override
  @JsonKey()
  final int totalMissions;
  @override
  @JsonKey()
  final bool isResting;
  @override
  @JsonKey()
  final int restSecondsRemaining;
  @override
  final String? currentMissionId;
  @override
  final String? status;

  @override
  String toString() {
    return 'ProgramProgress(programId: $programId, currentMissionIndex: $currentMissionIndex, totalMissions: $totalMissions, isResting: $isResting, restSecondsRemaining: $restSecondsRemaining, currentMissionId: $currentMissionId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProgramProgressImpl &&
            (identical(other.programId, programId) ||
                other.programId == programId) &&
            (identical(other.currentMissionIndex, currentMissionIndex) ||
                other.currentMissionIndex == currentMissionIndex) &&
            (identical(other.totalMissions, totalMissions) ||
                other.totalMissions == totalMissions) &&
            (identical(other.isResting, isResting) ||
                other.isResting == isResting) &&
            (identical(other.restSecondsRemaining, restSecondsRemaining) ||
                other.restSecondsRemaining == restSecondsRemaining) &&
            (identical(other.currentMissionId, currentMissionId) ||
                other.currentMissionId == currentMissionId) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, programId, currentMissionIndex,
      totalMissions, isResting, restSecondsRemaining, currentMissionId, status);

  /// Create a copy of ProgramProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProgramProgressImplCopyWith<_$ProgramProgressImpl> get copyWith =>
      __$$ProgramProgressImplCopyWithImpl<_$ProgramProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProgramProgressImplToJson(
      this,
    );
  }
}

abstract class _ProgramProgress extends ProgramProgress {
  const factory _ProgramProgress(
      {required final String programId,
      final int currentMissionIndex,
      final int totalMissions,
      final bool isResting,
      final int restSecondsRemaining,
      final String? currentMissionId,
      final String? status}) = _$ProgramProgressImpl;
  const _ProgramProgress._() : super._();

  factory _ProgramProgress.fromJson(Map<String, dynamic> json) =
      _$ProgramProgressImpl.fromJson;

  @override
  String get programId;
  @override
  int get currentMissionIndex;
  @override
  int get totalMissions;
  @override
  bool get isResting;
  @override
  int get restSecondsRemaining;
  @override
  String? get currentMissionId;
  @override
  String? get status;

  /// Create a copy of ProgramProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProgramProgressImplCopyWith<_$ProgramProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
