// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MissionSchedule _$MissionScheduleFromJson(Map<String, dynamic> json) {
  return _MissionSchedule.fromJson(json);
}

/// @nodoc
mixin _$MissionSchedule {
  /// Schedule ID (robot uses schedule_id)
  @JsonKey(name: 'schedule_id')
  String get id => throw _privateConstructorUsedError;

  /// Mission name to run
  @JsonKey(name: 'mission_name')
  String get missionName => throw _privateConstructorUsedError;

  /// Dog ID this schedule is for
  @JsonKey(name: 'dog_id')
  String get dogId => throw _privateConstructorUsedError;

  /// Display name for the schedule
  String get name => throw _privateConstructorUsedError;

  /// Schedule type: once, daily, weekly
  ScheduleType get type => throw _privateConstructorUsedError;

  /// Start time in HH:MM format (e.g., "08:00")
  @JsonKey(name: 'start_time')
  String get startTime => throw _privateConstructorUsedError;

  /// End time in HH:MM format (e.g., "12:00")
  @JsonKey(name: 'end_time')
  String get endTime => throw _privateConstructorUsedError;

  /// Days of week as strings: ["monday", "tuesday", ...]
  @JsonKey(name: 'days_of_week')
  List<String> get daysOfWeek => throw _privateConstructorUsedError;

  /// Whether schedule is enabled
  bool get enabled => throw _privateConstructorUsedError;

  /// Hours between runs (cooldown)
  @JsonKey(name: 'cooldown_hours')
  int get cooldownHours => throw _privateConstructorUsedError;

  /// Server-provided timestamps
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MissionSchedule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MissionScheduleCopyWith<MissionSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissionScheduleCopyWith<$Res> {
  factory $MissionScheduleCopyWith(
          MissionSchedule value, $Res Function(MissionSchedule) then) =
      _$MissionScheduleCopyWithImpl<$Res, MissionSchedule>;
  @useResult
  $Res call(
      {@JsonKey(name: 'schedule_id') String id,
      @JsonKey(name: 'mission_name') String missionName,
      @JsonKey(name: 'dog_id') String dogId,
      String name,
      ScheduleType type,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'days_of_week') List<String> daysOfWeek,
      bool enabled,
      @JsonKey(name: 'cooldown_hours') int cooldownHours,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$MissionScheduleCopyWithImpl<$Res, $Val extends MissionSchedule>
    implements $MissionScheduleCopyWith<$Res> {
  _$MissionScheduleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? missionName = null,
    Object? dogId = null,
    Object? name = null,
    Object? type = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? daysOfWeek = null,
    Object? enabled = null,
    Object? cooldownHours = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      missionName: null == missionName
          ? _value.missionName
          : missionName // ignore: cast_nullable_to_non_nullable
              as String,
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ScheduleType,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      daysOfWeek: null == daysOfWeek
          ? _value.daysOfWeek
          : daysOfWeek // ignore: cast_nullable_to_non_nullable
              as List<String>,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      cooldownHours: null == cooldownHours
          ? _value.cooldownHours
          : cooldownHours // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MissionScheduleImplCopyWith<$Res>
    implements $MissionScheduleCopyWith<$Res> {
  factory _$$MissionScheduleImplCopyWith(_$MissionScheduleImpl value,
          $Res Function(_$MissionScheduleImpl) then) =
      __$$MissionScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'schedule_id') String id,
      @JsonKey(name: 'mission_name') String missionName,
      @JsonKey(name: 'dog_id') String dogId,
      String name,
      ScheduleType type,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'days_of_week') List<String> daysOfWeek,
      bool enabled,
      @JsonKey(name: 'cooldown_hours') int cooldownHours,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$$MissionScheduleImplCopyWithImpl<$Res>
    extends _$MissionScheduleCopyWithImpl<$Res, _$MissionScheduleImpl>
    implements _$$MissionScheduleImplCopyWith<$Res> {
  __$$MissionScheduleImplCopyWithImpl(
      _$MissionScheduleImpl _value, $Res Function(_$MissionScheduleImpl) _then)
      : super(_value, _then);

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? missionName = null,
    Object? dogId = null,
    Object? name = null,
    Object? type = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? daysOfWeek = null,
    Object? enabled = null,
    Object? cooldownHours = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$MissionScheduleImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      missionName: null == missionName
          ? _value.missionName
          : missionName // ignore: cast_nullable_to_non_nullable
              as String,
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ScheduleType,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      daysOfWeek: null == daysOfWeek
          ? _value._daysOfWeek
          : daysOfWeek // ignore: cast_nullable_to_non_nullable
              as List<String>,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      cooldownHours: null == cooldownHours
          ? _value.cooldownHours
          : cooldownHours // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MissionScheduleImpl extends _MissionSchedule {
  const _$MissionScheduleImpl(
      {@JsonKey(name: 'schedule_id') required this.id,
      @JsonKey(name: 'mission_name') required this.missionName,
      @JsonKey(name: 'dog_id') required this.dogId,
      this.name = '',
      required this.type,
      @JsonKey(name: 'start_time') required this.startTime,
      @JsonKey(name: 'end_time') required this.endTime,
      @JsonKey(name: 'days_of_week') final List<String> daysOfWeek = const [],
      this.enabled = true,
      @JsonKey(name: 'cooldown_hours') this.cooldownHours = 24,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _daysOfWeek = daysOfWeek,
        super._();

  factory _$MissionScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$MissionScheduleImplFromJson(json);

  /// Schedule ID (robot uses schedule_id)
  @override
  @JsonKey(name: 'schedule_id')
  final String id;

  /// Mission name to run
  @override
  @JsonKey(name: 'mission_name')
  final String missionName;

  /// Dog ID this schedule is for
  @override
  @JsonKey(name: 'dog_id')
  final String dogId;

  /// Display name for the schedule
  @override
  @JsonKey()
  final String name;

  /// Schedule type: once, daily, weekly
  @override
  final ScheduleType type;

  /// Start time in HH:MM format (e.g., "08:00")
  @override
  @JsonKey(name: 'start_time')
  final String startTime;

  /// End time in HH:MM format (e.g., "12:00")
  @override
  @JsonKey(name: 'end_time')
  final String endTime;

  /// Days of week as strings: ["monday", "tuesday", ...]
  final List<String> _daysOfWeek;

  /// Days of week as strings: ["monday", "tuesday", ...]
  @override
  @JsonKey(name: 'days_of_week')
  List<String> get daysOfWeek {
    if (_daysOfWeek is EqualUnmodifiableListView) return _daysOfWeek;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_daysOfWeek);
  }

  /// Whether schedule is enabled
  @override
  @JsonKey()
  final bool enabled;

  /// Hours between runs (cooldown)
  @override
  @JsonKey(name: 'cooldown_hours')
  final int cooldownHours;

  /// Server-provided timestamps
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'MissionSchedule(id: $id, missionName: $missionName, dogId: $dogId, name: $name, type: $type, startTime: $startTime, endTime: $endTime, daysOfWeek: $daysOfWeek, enabled: $enabled, cooldownHours: $cooldownHours, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissionScheduleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.missionName, missionName) ||
                other.missionName == missionName) &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            const DeepCollectionEquality()
                .equals(other._daysOfWeek, _daysOfWeek) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.cooldownHours, cooldownHours) ||
                other.cooldownHours == cooldownHours) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      missionName,
      dogId,
      name,
      type,
      startTime,
      endTime,
      const DeepCollectionEquality().hash(_daysOfWeek),
      enabled,
      cooldownHours,
      createdAt,
      updatedAt);

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MissionScheduleImplCopyWith<_$MissionScheduleImpl> get copyWith =>
      __$$MissionScheduleImplCopyWithImpl<_$MissionScheduleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MissionScheduleImplToJson(
      this,
    );
  }
}

abstract class _MissionSchedule extends MissionSchedule {
  const factory _MissionSchedule(
          {@JsonKey(name: 'schedule_id') required final String id,
          @JsonKey(name: 'mission_name') required final String missionName,
          @JsonKey(name: 'dog_id') required final String dogId,
          final String name,
          required final ScheduleType type,
          @JsonKey(name: 'start_time') required final String startTime,
          @JsonKey(name: 'end_time') required final String endTime,
          @JsonKey(name: 'days_of_week') final List<String> daysOfWeek,
          final bool enabled,
          @JsonKey(name: 'cooldown_hours') final int cooldownHours,
          @JsonKey(name: 'created_at') final DateTime? createdAt,
          @JsonKey(name: 'updated_at') final DateTime? updatedAt}) =
      _$MissionScheduleImpl;
  const _MissionSchedule._() : super._();

  factory _MissionSchedule.fromJson(Map<String, dynamic> json) =
      _$MissionScheduleImpl.fromJson;

  /// Schedule ID (robot uses schedule_id)
  @override
  @JsonKey(name: 'schedule_id')
  String get id;

  /// Mission name to run
  @override
  @JsonKey(name: 'mission_name')
  String get missionName;

  /// Dog ID this schedule is for
  @override
  @JsonKey(name: 'dog_id')
  String get dogId;

  /// Display name for the schedule
  @override
  String get name;

  /// Schedule type: once, daily, weekly
  @override
  ScheduleType get type;

  /// Start time in HH:MM format (e.g., "08:00")
  @override
  @JsonKey(name: 'start_time')
  String get startTime;

  /// End time in HH:MM format (e.g., "12:00")
  @override
  @JsonKey(name: 'end_time')
  String get endTime;

  /// Days of week as strings: ["monday", "tuesday", ...]
  @override
  @JsonKey(name: 'days_of_week')
  List<String> get daysOfWeek;

  /// Whether schedule is enabled
  @override
  bool get enabled;

  /// Hours between runs (cooldown)
  @override
  @JsonKey(name: 'cooldown_hours')
  int get cooldownHours;

  /// Server-provided timestamps
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MissionScheduleImplCopyWith<_$MissionScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
