// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dog_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DogProfile _$DogProfileFromJson(Map<String, dynamic> json) {
  return _DogProfile.fromJson(json);
}

/// @nodoc
mixin _$DogProfile {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get breed => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get localPhotoPath => throw _privateConstructorUsedError;
  DateTime? get birthDate => throw _privateConstructorUsedError;
  double? get weight => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DogColor get color => throw _privateConstructorUsedError;
  int? get arucoMarkerId => throw _privateConstructorUsedError;
  List<String> get goals => throw _privateConstructorUsedError;
  String? get lastMissionId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this DogProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DogProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DogProfileCopyWith<DogProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DogProfileCopyWith<$Res> {
  factory $DogProfileCopyWith(
          DogProfile value, $Res Function(DogProfile) then) =
      _$DogProfileCopyWithImpl<$Res, DogProfile>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? breed,
      String? photoUrl,
      String? localPhotoPath,
      DateTime? birthDate,
      double? weight,
      String? notes,
      DogColor color,
      int? arucoMarkerId,
      List<String> goals,
      String? lastMissionId,
      DateTime? createdAt});
}

/// @nodoc
class _$DogProfileCopyWithImpl<$Res, $Val extends DogProfile>
    implements $DogProfileCopyWith<$Res> {
  _$DogProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DogProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? breed = freezed,
    Object? photoUrl = freezed,
    Object? localPhotoPath = freezed,
    Object? birthDate = freezed,
    Object? weight = freezed,
    Object? notes = freezed,
    Object? color = null,
    Object? arucoMarkerId = freezed,
    Object? goals = null,
    Object? lastMissionId = freezed,
    Object? createdAt = freezed,
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
      breed: freezed == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      localPhotoPath: freezed == localPhotoPath
          ? _value.localPhotoPath
          : localPhotoPath // ignore: cast_nullable_to_non_nullable
              as String?,
      birthDate: freezed == birthDate
          ? _value.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      weight: freezed == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as DogColor,
      arucoMarkerId: freezed == arucoMarkerId
          ? _value.arucoMarkerId
          : arucoMarkerId // ignore: cast_nullable_to_non_nullable
              as int?,
      goals: null == goals
          ? _value.goals
          : goals // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMissionId: freezed == lastMissionId
          ? _value.lastMissionId
          : lastMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DogProfileImplCopyWith<$Res>
    implements $DogProfileCopyWith<$Res> {
  factory _$$DogProfileImplCopyWith(
          _$DogProfileImpl value, $Res Function(_$DogProfileImpl) then) =
      __$$DogProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? breed,
      String? photoUrl,
      String? localPhotoPath,
      DateTime? birthDate,
      double? weight,
      String? notes,
      DogColor color,
      int? arucoMarkerId,
      List<String> goals,
      String? lastMissionId,
      DateTime? createdAt});
}

/// @nodoc
class __$$DogProfileImplCopyWithImpl<$Res>
    extends _$DogProfileCopyWithImpl<$Res, _$DogProfileImpl>
    implements _$$DogProfileImplCopyWith<$Res> {
  __$$DogProfileImplCopyWithImpl(
      _$DogProfileImpl _value, $Res Function(_$DogProfileImpl) _then)
      : super(_value, _then);

  /// Create a copy of DogProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? breed = freezed,
    Object? photoUrl = freezed,
    Object? localPhotoPath = freezed,
    Object? birthDate = freezed,
    Object? weight = freezed,
    Object? notes = freezed,
    Object? color = null,
    Object? arucoMarkerId = freezed,
    Object? goals = null,
    Object? lastMissionId = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$DogProfileImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      breed: freezed == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      localPhotoPath: freezed == localPhotoPath
          ? _value.localPhotoPath
          : localPhotoPath // ignore: cast_nullable_to_non_nullable
              as String?,
      birthDate: freezed == birthDate
          ? _value.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      weight: freezed == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as double?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as DogColor,
      arucoMarkerId: freezed == arucoMarkerId
          ? _value.arucoMarkerId
          : arucoMarkerId // ignore: cast_nullable_to_non_nullable
              as int?,
      goals: null == goals
          ? _value._goals
          : goals // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMissionId: freezed == lastMissionId
          ? _value.lastMissionId
          : lastMissionId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DogProfileImpl implements _DogProfile {
  const _$DogProfileImpl(
      {required this.id,
      required this.name,
      this.breed,
      this.photoUrl,
      this.localPhotoPath,
      this.birthDate,
      this.weight,
      this.notes,
      this.color = DogColor.mixed,
      this.arucoMarkerId,
      final List<String> goals = const [],
      this.lastMissionId,
      this.createdAt})
      : _goals = goals;

  factory _$DogProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$DogProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? breed;
  @override
  final String? photoUrl;
  @override
  final String? localPhotoPath;
  @override
  final DateTime? birthDate;
  @override
  final double? weight;
  @override
  final String? notes;
  @override
  @JsonKey()
  final DogColor color;
  @override
  final int? arucoMarkerId;
  final List<String> _goals;
  @override
  @JsonKey()
  List<String> get goals {
    if (_goals is EqualUnmodifiableListView) return _goals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_goals);
  }

  @override
  final String? lastMissionId;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'DogProfile(id: $id, name: $name, breed: $breed, photoUrl: $photoUrl, localPhotoPath: $localPhotoPath, birthDate: $birthDate, weight: $weight, notes: $notes, color: $color, arucoMarkerId: $arucoMarkerId, goals: $goals, lastMissionId: $lastMissionId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DogProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.breed, breed) || other.breed == breed) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.localPhotoPath, localPhotoPath) ||
                other.localPhotoPath == localPhotoPath) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.arucoMarkerId, arucoMarkerId) ||
                other.arucoMarkerId == arucoMarkerId) &&
            const DeepCollectionEquality().equals(other._goals, _goals) &&
            (identical(other.lastMissionId, lastMissionId) ||
                other.lastMissionId == lastMissionId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      breed,
      photoUrl,
      localPhotoPath,
      birthDate,
      weight,
      notes,
      color,
      arucoMarkerId,
      const DeepCollectionEquality().hash(_goals),
      lastMissionId,
      createdAt);

  /// Create a copy of DogProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DogProfileImplCopyWith<_$DogProfileImpl> get copyWith =>
      __$$DogProfileImplCopyWithImpl<_$DogProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DogProfileImplToJson(
      this,
    );
  }
}

abstract class _DogProfile implements DogProfile {
  const factory _DogProfile(
      {required final String id,
      required final String name,
      final String? breed,
      final String? photoUrl,
      final String? localPhotoPath,
      final DateTime? birthDate,
      final double? weight,
      final String? notes,
      final DogColor color,
      final int? arucoMarkerId,
      final List<String> goals,
      final String? lastMissionId,
      final DateTime? createdAt}) = _$DogProfileImpl;

  factory _DogProfile.fromJson(Map<String, dynamic> json) =
      _$DogProfileImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get breed;
  @override
  String? get photoUrl;
  @override
  String? get localPhotoPath;
  @override
  DateTime? get birthDate;
  @override
  double? get weight;
  @override
  String? get notes;
  @override
  DogColor get color;
  @override
  int? get arucoMarkerId;
  @override
  List<String> get goals;
  @override
  String? get lastMissionId;
  @override
  DateTime? get createdAt;

  /// Create a copy of DogProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DogProfileImplCopyWith<_$DogProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DogDailySummary _$DogDailySummaryFromJson(Map<String, dynamic> json) {
  return _DogDailySummary.fromJson(json);
}

/// @nodoc
mixin _$DogDailySummary {
  String get dogId => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  int get treatCount => throw _privateConstructorUsedError;
  int get sitCount => throw _privateConstructorUsedError;
  int get barkCount => throw _privateConstructorUsedError;
  double get goalProgress => throw _privateConstructorUsedError;
  int get missionCount => throw _privateConstructorUsedError;
  int get missionSuccessCount => throw _privateConstructorUsedError;

  /// Serializes this DogDailySummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DogDailySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DogDailySummaryCopyWith<DogDailySummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DogDailySummaryCopyWith<$Res> {
  factory $DogDailySummaryCopyWith(
          DogDailySummary value, $Res Function(DogDailySummary) then) =
      _$DogDailySummaryCopyWithImpl<$Res, DogDailySummary>;
  @useResult
  $Res call(
      {String dogId,
      DateTime date,
      int treatCount,
      int sitCount,
      int barkCount,
      double goalProgress,
      int missionCount,
      int missionSuccessCount});
}

/// @nodoc
class _$DogDailySummaryCopyWithImpl<$Res, $Val extends DogDailySummary>
    implements $DogDailySummaryCopyWith<$Res> {
  _$DogDailySummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DogDailySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? date = null,
    Object? treatCount = null,
    Object? sitCount = null,
    Object? barkCount = null,
    Object? goalProgress = null,
    Object? missionCount = null,
    Object? missionSuccessCount = null,
  }) {
    return _then(_value.copyWith(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      treatCount: null == treatCount
          ? _value.treatCount
          : treatCount // ignore: cast_nullable_to_non_nullable
              as int,
      sitCount: null == sitCount
          ? _value.sitCount
          : sitCount // ignore: cast_nullable_to_non_nullable
              as int,
      barkCount: null == barkCount
          ? _value.barkCount
          : barkCount // ignore: cast_nullable_to_non_nullable
              as int,
      goalProgress: null == goalProgress
          ? _value.goalProgress
          : goalProgress // ignore: cast_nullable_to_non_nullable
              as double,
      missionCount: null == missionCount
          ? _value.missionCount
          : missionCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionSuccessCount: null == missionSuccessCount
          ? _value.missionSuccessCount
          : missionSuccessCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DogDailySummaryImplCopyWith<$Res>
    implements $DogDailySummaryCopyWith<$Res> {
  factory _$$DogDailySummaryImplCopyWith(_$DogDailySummaryImpl value,
          $Res Function(_$DogDailySummaryImpl) then) =
      __$$DogDailySummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String dogId,
      DateTime date,
      int treatCount,
      int sitCount,
      int barkCount,
      double goalProgress,
      int missionCount,
      int missionSuccessCount});
}

/// @nodoc
class __$$DogDailySummaryImplCopyWithImpl<$Res>
    extends _$DogDailySummaryCopyWithImpl<$Res, _$DogDailySummaryImpl>
    implements _$$DogDailySummaryImplCopyWith<$Res> {
  __$$DogDailySummaryImplCopyWithImpl(
      _$DogDailySummaryImpl _value, $Res Function(_$DogDailySummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of DogDailySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? date = null,
    Object? treatCount = null,
    Object? sitCount = null,
    Object? barkCount = null,
    Object? goalProgress = null,
    Object? missionCount = null,
    Object? missionSuccessCount = null,
  }) {
    return _then(_$DogDailySummaryImpl(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      treatCount: null == treatCount
          ? _value.treatCount
          : treatCount // ignore: cast_nullable_to_non_nullable
              as int,
      sitCount: null == sitCount
          ? _value.sitCount
          : sitCount // ignore: cast_nullable_to_non_nullable
              as int,
      barkCount: null == barkCount
          ? _value.barkCount
          : barkCount // ignore: cast_nullable_to_non_nullable
              as int,
      goalProgress: null == goalProgress
          ? _value.goalProgress
          : goalProgress // ignore: cast_nullable_to_non_nullable
              as double,
      missionCount: null == missionCount
          ? _value.missionCount
          : missionCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionSuccessCount: null == missionSuccessCount
          ? _value.missionSuccessCount
          : missionSuccessCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DogDailySummaryImpl implements _DogDailySummary {
  const _$DogDailySummaryImpl(
      {required this.dogId,
      required this.date,
      this.treatCount = 0,
      this.sitCount = 0,
      this.barkCount = 0,
      this.goalProgress = 0.0,
      this.missionCount = 0,
      this.missionSuccessCount = 0});

  factory _$DogDailySummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$DogDailySummaryImplFromJson(json);

  @override
  final String dogId;
  @override
  final DateTime date;
  @override
  @JsonKey()
  final int treatCount;
  @override
  @JsonKey()
  final int sitCount;
  @override
  @JsonKey()
  final int barkCount;
  @override
  @JsonKey()
  final double goalProgress;
  @override
  @JsonKey()
  final int missionCount;
  @override
  @JsonKey()
  final int missionSuccessCount;

  @override
  String toString() {
    return 'DogDailySummary(dogId: $dogId, date: $date, treatCount: $treatCount, sitCount: $sitCount, barkCount: $barkCount, goalProgress: $goalProgress, missionCount: $missionCount, missionSuccessCount: $missionSuccessCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DogDailySummaryImpl &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.treatCount, treatCount) ||
                other.treatCount == treatCount) &&
            (identical(other.sitCount, sitCount) ||
                other.sitCount == sitCount) &&
            (identical(other.barkCount, barkCount) ||
                other.barkCount == barkCount) &&
            (identical(other.goalProgress, goalProgress) ||
                other.goalProgress == goalProgress) &&
            (identical(other.missionCount, missionCount) ||
                other.missionCount == missionCount) &&
            (identical(other.missionSuccessCount, missionSuccessCount) ||
                other.missionSuccessCount == missionSuccessCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dogId, date, treatCount,
      sitCount, barkCount, goalProgress, missionCount, missionSuccessCount);

  /// Create a copy of DogDailySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DogDailySummaryImplCopyWith<_$DogDailySummaryImpl> get copyWith =>
      __$$DogDailySummaryImplCopyWithImpl<_$DogDailySummaryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DogDailySummaryImplToJson(
      this,
    );
  }
}

abstract class _DogDailySummary implements DogDailySummary {
  const factory _DogDailySummary(
      {required final String dogId,
      required final DateTime date,
      final int treatCount,
      final int sitCount,
      final int barkCount,
      final double goalProgress,
      final int missionCount,
      final int missionSuccessCount}) = _$DogDailySummaryImpl;

  factory _DogDailySummary.fromJson(Map<String, dynamic> json) =
      _$DogDailySummaryImpl.fromJson;

  @override
  String get dogId;
  @override
  DateTime get date;
  @override
  int get treatCount;
  @override
  int get sitCount;
  @override
  int get barkCount;
  @override
  double get goalProgress;
  @override
  int get missionCount;
  @override
  int get missionSuccessCount;

  /// Create a copy of DogDailySummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DogDailySummaryImplCopyWith<_$DogDailySummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
