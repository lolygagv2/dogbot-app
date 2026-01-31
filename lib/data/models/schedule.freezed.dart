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
  String get id => throw _privateConstructorUsedError;
  String get missionId => throw _privateConstructorUsedError;
  String get dogId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  ScheduleType get type => throw _privateConstructorUsedError;
  int get hour => throw _privateConstructorUsedError; // 0-23
  int get minute => throw _privateConstructorUsedError; // 0-59
  List<int> get weekdays =>
      throw _privateConstructorUsedError; // For weekly: 0=Sun, 1=Mon, ..., 6=Sat
  bool get enabled => throw _privateConstructorUsedError;
  DateTime? get nextRun => throw _privateConstructorUsedError;

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
      {String id,
      String missionId,
      String dogId,
      String name,
      ScheduleType type,
      int hour,
      int minute,
      List<int> weekdays,
      bool enabled,
      DateTime? nextRun});
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
    Object? missionId = null,
    Object? dogId = null,
    Object? name = null,
    Object? type = null,
    Object? hour = null,
    Object? minute = null,
    Object? weekdays = null,
    Object? enabled = null,
    Object? nextRun = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      missionId: null == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
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
      hour: null == hour
          ? _value.hour
          : hour // ignore: cast_nullable_to_non_nullable
              as int,
      minute: null == minute
          ? _value.minute
          : minute // ignore: cast_nullable_to_non_nullable
              as int,
      weekdays: null == weekdays
          ? _value.weekdays
          : weekdays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      nextRun: freezed == nextRun
          ? _value.nextRun
          : nextRun // ignore: cast_nullable_to_non_nullable
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
      {String id,
      String missionId,
      String dogId,
      String name,
      ScheduleType type,
      int hour,
      int minute,
      List<int> weekdays,
      bool enabled,
      DateTime? nextRun});
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
    Object? missionId = null,
    Object? dogId = null,
    Object? name = null,
    Object? type = null,
    Object? hour = null,
    Object? minute = null,
    Object? weekdays = null,
    Object? enabled = null,
    Object? nextRun = freezed,
  }) {
    return _then(_$MissionScheduleImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      missionId: null == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
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
      hour: null == hour
          ? _value.hour
          : hour // ignore: cast_nullable_to_non_nullable
              as int,
      minute: null == minute
          ? _value.minute
          : minute // ignore: cast_nullable_to_non_nullable
              as int,
      weekdays: null == weekdays
          ? _value._weekdays
          : weekdays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      nextRun: freezed == nextRun
          ? _value.nextRun
          : nextRun // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MissionScheduleImpl extends _MissionSchedule {
  const _$MissionScheduleImpl(
      {required this.id,
      required this.missionId,
      required this.dogId,
      this.name = '',
      required this.type,
      required this.hour,
      required this.minute,
      final List<int> weekdays = const [],
      this.enabled = true,
      this.nextRun})
      : _weekdays = weekdays,
        super._();

  factory _$MissionScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$MissionScheduleImplFromJson(json);

  @override
  final String id;
  @override
  final String missionId;
  @override
  final String dogId;
  @override
  @JsonKey()
  final String name;
  @override
  final ScheduleType type;
  @override
  final int hour;
// 0-23
  @override
  final int minute;
// 0-59
  final List<int> _weekdays;
// 0-59
  @override
  @JsonKey()
  List<int> get weekdays {
    if (_weekdays is EqualUnmodifiableListView) return _weekdays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weekdays);
  }

// For weekly: 0=Sun, 1=Mon, ..., 6=Sat
  @override
  @JsonKey()
  final bool enabled;
  @override
  final DateTime? nextRun;

  @override
  String toString() {
    return 'MissionSchedule(id: $id, missionId: $missionId, dogId: $dogId, name: $name, type: $type, hour: $hour, minute: $minute, weekdays: $weekdays, enabled: $enabled, nextRun: $nextRun)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissionScheduleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.missionId, missionId) ||
                other.missionId == missionId) &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.hour, hour) || other.hour == hour) &&
            (identical(other.minute, minute) || other.minute == minute) &&
            const DeepCollectionEquality().equals(other._weekdays, _weekdays) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.nextRun, nextRun) || other.nextRun == nextRun));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      missionId,
      dogId,
      name,
      type,
      hour,
      minute,
      const DeepCollectionEquality().hash(_weekdays),
      enabled,
      nextRun);

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
      {required final String id,
      required final String missionId,
      required final String dogId,
      final String name,
      required final ScheduleType type,
      required final int hour,
      required final int minute,
      final List<int> weekdays,
      final bool enabled,
      final DateTime? nextRun}) = _$MissionScheduleImpl;
  const _MissionSchedule._() : super._();

  factory _MissionSchedule.fromJson(Map<String, dynamic> json) =
      _$MissionScheduleImpl.fromJson;

  @override
  String get id;
  @override
  String get missionId;
  @override
  String get dogId;
  @override
  String get name;
  @override
  ScheduleType get type;
  @override
  int get hour; // 0-23
  @override
  int get minute; // 0-59
  @override
  List<int> get weekdays; // For weekly: 0=Sun, 1=Mon, ..., 6=Sat
  @override
  bool get enabled;
  @override
  DateTime? get nextRun;

  /// Create a copy of MissionSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MissionScheduleImplCopyWith<_$MissionScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
