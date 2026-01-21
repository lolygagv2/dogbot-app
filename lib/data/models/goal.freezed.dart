// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Goal _$GoalFromJson(Map<String, dynamic> json) {
  return _Goal.fromJson(json);
}

/// @nodoc
mixin _$Goal {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get metric => throw _privateConstructorUsedError;
  GoalComparison get comparison => throw _privateConstructorUsedError;
  double get targetValue => throw _privateConstructorUsedError;
  double get currentValue => throw _privateConstructorUsedError;
  GoalPeriod get period => throw _privateConstructorUsedError;
  String? get dogId => throw _privateConstructorUsedError;
  DateTime? get deadline => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this Goal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GoalCopyWith<Goal> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GoalCopyWith<$Res> {
  factory $GoalCopyWith(Goal value, $Res Function(Goal) then) =
      _$GoalCopyWithImpl<$Res, Goal>;
  @useResult
  $Res call(
      {String id,
      String title,
      String metric,
      GoalComparison comparison,
      double targetValue,
      double currentValue,
      GoalPeriod period,
      String? dogId,
      DateTime? deadline,
      DateTime? createdAt,
      bool isActive});
}

/// @nodoc
class _$GoalCopyWithImpl<$Res, $Val extends Goal>
    implements $GoalCopyWith<$Res> {
  _$GoalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? metric = null,
    Object? comparison = null,
    Object? targetValue = null,
    Object? currentValue = null,
    Object? period = null,
    Object? dogId = freezed,
    Object? deadline = freezed,
    Object? createdAt = freezed,
    Object? isActive = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      metric: null == metric
          ? _value.metric
          : metric // ignore: cast_nullable_to_non_nullable
              as String,
      comparison: null == comparison
          ? _value.comparison
          : comparison // ignore: cast_nullable_to_non_nullable
              as GoalComparison,
      targetValue: null == targetValue
          ? _value.targetValue
          : targetValue // ignore: cast_nullable_to_non_nullable
              as double,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as double,
      period: null == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as GoalPeriod,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GoalImplCopyWith<$Res> implements $GoalCopyWith<$Res> {
  factory _$$GoalImplCopyWith(
          _$GoalImpl value, $Res Function(_$GoalImpl) then) =
      __$$GoalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String metric,
      GoalComparison comparison,
      double targetValue,
      double currentValue,
      GoalPeriod period,
      String? dogId,
      DateTime? deadline,
      DateTime? createdAt,
      bool isActive});
}

/// @nodoc
class __$$GoalImplCopyWithImpl<$Res>
    extends _$GoalCopyWithImpl<$Res, _$GoalImpl>
    implements _$$GoalImplCopyWith<$Res> {
  __$$GoalImplCopyWithImpl(_$GoalImpl _value, $Res Function(_$GoalImpl) _then)
      : super(_value, _then);

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? metric = null,
    Object? comparison = null,
    Object? targetValue = null,
    Object? currentValue = null,
    Object? period = null,
    Object? dogId = freezed,
    Object? deadline = freezed,
    Object? createdAt = freezed,
    Object? isActive = null,
  }) {
    return _then(_$GoalImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      metric: null == metric
          ? _value.metric
          : metric // ignore: cast_nullable_to_non_nullable
              as String,
      comparison: null == comparison
          ? _value.comparison
          : comparison // ignore: cast_nullable_to_non_nullable
              as GoalComparison,
      targetValue: null == targetValue
          ? _value.targetValue
          : targetValue // ignore: cast_nullable_to_non_nullable
              as double,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as double,
      period: null == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as GoalPeriod,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GoalImpl extends _Goal {
  const _$GoalImpl(
      {required this.id,
      required this.title,
      required this.metric,
      required this.comparison,
      required this.targetValue,
      required this.currentValue,
      required this.period,
      this.dogId,
      this.deadline,
      this.createdAt,
      this.isActive = true})
      : super._();

  factory _$GoalImpl.fromJson(Map<String, dynamic> json) =>
      _$$GoalImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String metric;
  @override
  final GoalComparison comparison;
  @override
  final double targetValue;
  @override
  final double currentValue;
  @override
  final GoalPeriod period;
  @override
  final String? dogId;
  @override
  final DateTime? deadline;
  @override
  final DateTime? createdAt;
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'Goal(id: $id, title: $title, metric: $metric, comparison: $comparison, targetValue: $targetValue, currentValue: $currentValue, period: $period, dogId: $dogId, deadline: $deadline, createdAt: $createdAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GoalImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.metric, metric) || other.metric == metric) &&
            (identical(other.comparison, comparison) ||
                other.comparison == comparison) &&
            (identical(other.targetValue, targetValue) ||
                other.targetValue == targetValue) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, metric, comparison,
      targetValue, currentValue, period, dogId, deadline, createdAt, isActive);

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GoalImplCopyWith<_$GoalImpl> get copyWith =>
      __$$GoalImplCopyWithImpl<_$GoalImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GoalImplToJson(
      this,
    );
  }
}

abstract class _Goal extends Goal {
  const factory _Goal(
      {required final String id,
      required final String title,
      required final String metric,
      required final GoalComparison comparison,
      required final double targetValue,
      required final double currentValue,
      required final GoalPeriod period,
      final String? dogId,
      final DateTime? deadline,
      final DateTime? createdAt,
      final bool isActive}) = _$GoalImpl;
  const _Goal._() : super._();

  factory _Goal.fromJson(Map<String, dynamic> json) = _$GoalImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get metric;
  @override
  GoalComparison get comparison;
  @override
  double get targetValue;
  @override
  double get currentValue;
  @override
  GoalPeriod get period;
  @override
  String? get dogId;
  @override
  DateTime? get deadline;
  @override
  DateTime? get createdAt;
  @override
  bool get isActive;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GoalImplCopyWith<_$GoalImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
