// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DailyStats _$DailyStatsFromJson(Map<String, dynamic> json) {
  return _DailyStats.fromJson(json);
}

/// @nodoc
mixin _$DailyStats {
  DateTime get date => throw _privateConstructorUsedError;
  int get barkCount => throw _privateConstructorUsedError;
  int get sitCount => throw _privateConstructorUsedError;
  int get treatCount => throw _privateConstructorUsedError;
  int get missionCount => throw _privateConstructorUsedError;
  int get missionSuccessCount => throw _privateConstructorUsedError;
  Duration get totalActiveTime => throw _privateConstructorUsedError;

  /// Serializes this DailyStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyStatsCopyWith<DailyStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyStatsCopyWith<$Res> {
  factory $DailyStatsCopyWith(
          DailyStats value, $Res Function(DailyStats) then) =
      _$DailyStatsCopyWithImpl<$Res, DailyStats>;
  @useResult
  $Res call(
      {DateTime date,
      int barkCount,
      int sitCount,
      int treatCount,
      int missionCount,
      int missionSuccessCount,
      Duration totalActiveTime});
}

/// @nodoc
class _$DailyStatsCopyWithImpl<$Res, $Val extends DailyStats>
    implements $DailyStatsCopyWith<$Res> {
  _$DailyStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? barkCount = null,
    Object? sitCount = null,
    Object? treatCount = null,
    Object? missionCount = null,
    Object? missionSuccessCount = null,
    Object? totalActiveTime = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      barkCount: null == barkCount
          ? _value.barkCount
          : barkCount // ignore: cast_nullable_to_non_nullable
              as int,
      sitCount: null == sitCount
          ? _value.sitCount
          : sitCount // ignore: cast_nullable_to_non_nullable
              as int,
      treatCount: null == treatCount
          ? _value.treatCount
          : treatCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionCount: null == missionCount
          ? _value.missionCount
          : missionCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionSuccessCount: null == missionSuccessCount
          ? _value.missionSuccessCount
          : missionSuccessCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTime: null == totalActiveTime
          ? _value.totalActiveTime
          : totalActiveTime // ignore: cast_nullable_to_non_nullable
              as Duration,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyStatsImplCopyWith<$Res>
    implements $DailyStatsCopyWith<$Res> {
  factory _$$DailyStatsImplCopyWith(
          _$DailyStatsImpl value, $Res Function(_$DailyStatsImpl) then) =
      __$$DailyStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime date,
      int barkCount,
      int sitCount,
      int treatCount,
      int missionCount,
      int missionSuccessCount,
      Duration totalActiveTime});
}

/// @nodoc
class __$$DailyStatsImplCopyWithImpl<$Res>
    extends _$DailyStatsCopyWithImpl<$Res, _$DailyStatsImpl>
    implements _$$DailyStatsImplCopyWith<$Res> {
  __$$DailyStatsImplCopyWithImpl(
      _$DailyStatsImpl _value, $Res Function(_$DailyStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DailyStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? barkCount = null,
    Object? sitCount = null,
    Object? treatCount = null,
    Object? missionCount = null,
    Object? missionSuccessCount = null,
    Object? totalActiveTime = null,
  }) {
    return _then(_$DailyStatsImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      barkCount: null == barkCount
          ? _value.barkCount
          : barkCount // ignore: cast_nullable_to_non_nullable
              as int,
      sitCount: null == sitCount
          ? _value.sitCount
          : sitCount // ignore: cast_nullable_to_non_nullable
              as int,
      treatCount: null == treatCount
          ? _value.treatCount
          : treatCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionCount: null == missionCount
          ? _value.missionCount
          : missionCount // ignore: cast_nullable_to_non_nullable
              as int,
      missionSuccessCount: null == missionSuccessCount
          ? _value.missionSuccessCount
          : missionSuccessCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTime: null == totalActiveTime
          ? _value.totalActiveTime
          : totalActiveTime // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyStatsImpl extends _DailyStats {
  const _$DailyStatsImpl(
      {required this.date,
      this.barkCount = 0,
      this.sitCount = 0,
      this.treatCount = 0,
      this.missionCount = 0,
      this.missionSuccessCount = 0,
      this.totalActiveTime = Duration.zero})
      : super._();

  factory _$DailyStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyStatsImplFromJson(json);

  @override
  final DateTime date;
  @override
  @JsonKey()
  final int barkCount;
  @override
  @JsonKey()
  final int sitCount;
  @override
  @JsonKey()
  final int treatCount;
  @override
  @JsonKey()
  final int missionCount;
  @override
  @JsonKey()
  final int missionSuccessCount;
  @override
  @JsonKey()
  final Duration totalActiveTime;

  @override
  String toString() {
    return 'DailyStats(date: $date, barkCount: $barkCount, sitCount: $sitCount, treatCount: $treatCount, missionCount: $missionCount, missionSuccessCount: $missionSuccessCount, totalActiveTime: $totalActiveTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyStatsImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.barkCount, barkCount) ||
                other.barkCount == barkCount) &&
            (identical(other.sitCount, sitCount) ||
                other.sitCount == sitCount) &&
            (identical(other.treatCount, treatCount) ||
                other.treatCount == treatCount) &&
            (identical(other.missionCount, missionCount) ||
                other.missionCount == missionCount) &&
            (identical(other.missionSuccessCount, missionSuccessCount) ||
                other.missionSuccessCount == missionSuccessCount) &&
            (identical(other.totalActiveTime, totalActiveTime) ||
                other.totalActiveTime == totalActiveTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, barkCount, sitCount,
      treatCount, missionCount, missionSuccessCount, totalActiveTime);

  /// Create a copy of DailyStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyStatsImplCopyWith<_$DailyStatsImpl> get copyWith =>
      __$$DailyStatsImplCopyWithImpl<_$DailyStatsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyStatsImplToJson(
      this,
    );
  }
}

abstract class _DailyStats extends DailyStats {
  const factory _DailyStats(
      {required final DateTime date,
      final int barkCount,
      final int sitCount,
      final int treatCount,
      final int missionCount,
      final int missionSuccessCount,
      final Duration totalActiveTime}) = _$DailyStatsImpl;
  const _DailyStats._() : super._();

  factory _DailyStats.fromJson(Map<String, dynamic> json) =
      _$DailyStatsImpl.fromJson;

  @override
  DateTime get date;
  @override
  int get barkCount;
  @override
  int get sitCount;
  @override
  int get treatCount;
  @override
  int get missionCount;
  @override
  int get missionSuccessCount;
  @override
  Duration get totalActiveTime;

  /// Create a copy of DailyStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyStatsImplCopyWith<_$DailyStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnalyticsData _$AnalyticsDataFromJson(Map<String, dynamic> json) {
  return _AnalyticsData.fromJson(json);
}

/// @nodoc
mixin _$AnalyticsData {
  String get dogId => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  List<DailyStats> get dailyStats => throw _privateConstructorUsedError;
  Map<String, int> get behaviorDistribution =>
      throw _privateConstructorUsedError;
  Map<String, double> get missionSuccessRates =>
      throw _privateConstructorUsedError;

  /// Serializes this AnalyticsData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsDataCopyWith<AnalyticsData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsDataCopyWith<$Res> {
  factory $AnalyticsDataCopyWith(
          AnalyticsData value, $Res Function(AnalyticsData) then) =
      _$AnalyticsDataCopyWithImpl<$Res, AnalyticsData>;
  @useResult
  $Res call(
      {String dogId,
      DateTime startDate,
      DateTime endDate,
      List<DailyStats> dailyStats,
      Map<String, int> behaviorDistribution,
      Map<String, double> missionSuccessRates});
}

/// @nodoc
class _$AnalyticsDataCopyWithImpl<$Res, $Val extends AnalyticsData>
    implements $AnalyticsDataCopyWith<$Res> {
  _$AnalyticsDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? dailyStats = null,
    Object? behaviorDistribution = null,
    Object? missionSuccessRates = null,
  }) {
    return _then(_value.copyWith(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dailyStats: null == dailyStats
          ? _value.dailyStats
          : dailyStats // ignore: cast_nullable_to_non_nullable
              as List<DailyStats>,
      behaviorDistribution: null == behaviorDistribution
          ? _value.behaviorDistribution
          : behaviorDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      missionSuccessRates: null == missionSuccessRates
          ? _value.missionSuccessRates
          : missionSuccessRates // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnalyticsDataImplCopyWith<$Res>
    implements $AnalyticsDataCopyWith<$Res> {
  factory _$$AnalyticsDataImplCopyWith(
          _$AnalyticsDataImpl value, $Res Function(_$AnalyticsDataImpl) then) =
      __$$AnalyticsDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String dogId,
      DateTime startDate,
      DateTime endDate,
      List<DailyStats> dailyStats,
      Map<String, int> behaviorDistribution,
      Map<String, double> missionSuccessRates});
}

/// @nodoc
class __$$AnalyticsDataImplCopyWithImpl<$Res>
    extends _$AnalyticsDataCopyWithImpl<$Res, _$AnalyticsDataImpl>
    implements _$$AnalyticsDataImplCopyWith<$Res> {
  __$$AnalyticsDataImplCopyWithImpl(
      _$AnalyticsDataImpl _value, $Res Function(_$AnalyticsDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? dailyStats = null,
    Object? behaviorDistribution = null,
    Object? missionSuccessRates = null,
  }) {
    return _then(_$AnalyticsDataImpl(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dailyStats: null == dailyStats
          ? _value._dailyStats
          : dailyStats // ignore: cast_nullable_to_non_nullable
              as List<DailyStats>,
      behaviorDistribution: null == behaviorDistribution
          ? _value._behaviorDistribution
          : behaviorDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      missionSuccessRates: null == missionSuccessRates
          ? _value._missionSuccessRates
          : missionSuccessRates // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalyticsDataImpl extends _AnalyticsData {
  const _$AnalyticsDataImpl(
      {required this.dogId,
      required this.startDate,
      required this.endDate,
      final List<DailyStats> dailyStats = const [],
      final Map<String, int> behaviorDistribution = const {},
      final Map<String, double> missionSuccessRates = const {}})
      : _dailyStats = dailyStats,
        _behaviorDistribution = behaviorDistribution,
        _missionSuccessRates = missionSuccessRates,
        super._();

  factory _$AnalyticsDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalyticsDataImplFromJson(json);

  @override
  final String dogId;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  final List<DailyStats> _dailyStats;
  @override
  @JsonKey()
  List<DailyStats> get dailyStats {
    if (_dailyStats is EqualUnmodifiableListView) return _dailyStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dailyStats);
  }

  final Map<String, int> _behaviorDistribution;
  @override
  @JsonKey()
  Map<String, int> get behaviorDistribution {
    if (_behaviorDistribution is EqualUnmodifiableMapView)
      return _behaviorDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_behaviorDistribution);
  }

  final Map<String, double> _missionSuccessRates;
  @override
  @JsonKey()
  Map<String, double> get missionSuccessRates {
    if (_missionSuccessRates is EqualUnmodifiableMapView)
      return _missionSuccessRates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_missionSuccessRates);
  }

  @override
  String toString() {
    return 'AnalyticsData(dogId: $dogId, startDate: $startDate, endDate: $endDate, dailyStats: $dailyStats, behaviorDistribution: $behaviorDistribution, missionSuccessRates: $missionSuccessRates)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsDataImpl &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality()
                .equals(other._dailyStats, _dailyStats) &&
            const DeepCollectionEquality()
                .equals(other._behaviorDistribution, _behaviorDistribution) &&
            const DeepCollectionEquality()
                .equals(other._missionSuccessRates, _missionSuccessRates));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dogId,
      startDate,
      endDate,
      const DeepCollectionEquality().hash(_dailyStats),
      const DeepCollectionEquality().hash(_behaviorDistribution),
      const DeepCollectionEquality().hash(_missionSuccessRates));

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      __$$AnalyticsDataImplCopyWithImpl<_$AnalyticsDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalyticsDataImplToJson(
      this,
    );
  }
}

abstract class _AnalyticsData extends AnalyticsData {
  const factory _AnalyticsData(
      {required final String dogId,
      required final DateTime startDate,
      required final DateTime endDate,
      final List<DailyStats> dailyStats,
      final Map<String, int> behaviorDistribution,
      final Map<String, double> missionSuccessRates}) = _$AnalyticsDataImpl;
  const _AnalyticsData._() : super._();

  factory _AnalyticsData.fromJson(Map<String, dynamic> json) =
      _$AnalyticsDataImpl.fromJson;

  @override
  String get dogId;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  List<DailyStats> get dailyStats;
  @override
  Map<String, int> get behaviorDistribution;
  @override
  Map<String, double> get missionSuccessRates;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PeriodComparison _$PeriodComparisonFromJson(Map<String, dynamic> json) {
  return _PeriodComparison.fromJson(json);
}

/// @nodoc
mixin _$PeriodComparison {
  String get metric => throw _privateConstructorUsedError;
  double get currentValue => throw _privateConstructorUsedError;
  double get previousValue => throw _privateConstructorUsedError;
  double get changePercent => throw _privateConstructorUsedError;
  bool get isImprovement => throw _privateConstructorUsedError;

  /// Serializes this PeriodComparison to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PeriodComparison
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PeriodComparisonCopyWith<PeriodComparison> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PeriodComparisonCopyWith<$Res> {
  factory $PeriodComparisonCopyWith(
          PeriodComparison value, $Res Function(PeriodComparison) then) =
      _$PeriodComparisonCopyWithImpl<$Res, PeriodComparison>;
  @useResult
  $Res call(
      {String metric,
      double currentValue,
      double previousValue,
      double changePercent,
      bool isImprovement});
}

/// @nodoc
class _$PeriodComparisonCopyWithImpl<$Res, $Val extends PeriodComparison>
    implements $PeriodComparisonCopyWith<$Res> {
  _$PeriodComparisonCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PeriodComparison
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? metric = null,
    Object? currentValue = null,
    Object? previousValue = null,
    Object? changePercent = null,
    Object? isImprovement = null,
  }) {
    return _then(_value.copyWith(
      metric: null == metric
          ? _value.metric
          : metric // ignore: cast_nullable_to_non_nullable
              as String,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as double,
      previousValue: null == previousValue
          ? _value.previousValue
          : previousValue // ignore: cast_nullable_to_non_nullable
              as double,
      changePercent: null == changePercent
          ? _value.changePercent
          : changePercent // ignore: cast_nullable_to_non_nullable
              as double,
      isImprovement: null == isImprovement
          ? _value.isImprovement
          : isImprovement // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PeriodComparisonImplCopyWith<$Res>
    implements $PeriodComparisonCopyWith<$Res> {
  factory _$$PeriodComparisonImplCopyWith(_$PeriodComparisonImpl value,
          $Res Function(_$PeriodComparisonImpl) then) =
      __$$PeriodComparisonImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String metric,
      double currentValue,
      double previousValue,
      double changePercent,
      bool isImprovement});
}

/// @nodoc
class __$$PeriodComparisonImplCopyWithImpl<$Res>
    extends _$PeriodComparisonCopyWithImpl<$Res, _$PeriodComparisonImpl>
    implements _$$PeriodComparisonImplCopyWith<$Res> {
  __$$PeriodComparisonImplCopyWithImpl(_$PeriodComparisonImpl _value,
      $Res Function(_$PeriodComparisonImpl) _then)
      : super(_value, _then);

  /// Create a copy of PeriodComparison
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? metric = null,
    Object? currentValue = null,
    Object? previousValue = null,
    Object? changePercent = null,
    Object? isImprovement = null,
  }) {
    return _then(_$PeriodComparisonImpl(
      metric: null == metric
          ? _value.metric
          : metric // ignore: cast_nullable_to_non_nullable
              as String,
      currentValue: null == currentValue
          ? _value.currentValue
          : currentValue // ignore: cast_nullable_to_non_nullable
              as double,
      previousValue: null == previousValue
          ? _value.previousValue
          : previousValue // ignore: cast_nullable_to_non_nullable
              as double,
      changePercent: null == changePercent
          ? _value.changePercent
          : changePercent // ignore: cast_nullable_to_non_nullable
              as double,
      isImprovement: null == isImprovement
          ? _value.isImprovement
          : isImprovement // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PeriodComparisonImpl implements _PeriodComparison {
  const _$PeriodComparisonImpl(
      {required this.metric,
      required this.currentValue,
      required this.previousValue,
      required this.changePercent,
      required this.isImprovement});

  factory _$PeriodComparisonImpl.fromJson(Map<String, dynamic> json) =>
      _$$PeriodComparisonImplFromJson(json);

  @override
  final String metric;
  @override
  final double currentValue;
  @override
  final double previousValue;
  @override
  final double changePercent;
  @override
  final bool isImprovement;

  @override
  String toString() {
    return 'PeriodComparison(metric: $metric, currentValue: $currentValue, previousValue: $previousValue, changePercent: $changePercent, isImprovement: $isImprovement)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PeriodComparisonImpl &&
            (identical(other.metric, metric) || other.metric == metric) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue) &&
            (identical(other.previousValue, previousValue) ||
                other.previousValue == previousValue) &&
            (identical(other.changePercent, changePercent) ||
                other.changePercent == changePercent) &&
            (identical(other.isImprovement, isImprovement) ||
                other.isImprovement == isImprovement));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, metric, currentValue,
      previousValue, changePercent, isImprovement);

  /// Create a copy of PeriodComparison
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PeriodComparisonImplCopyWith<_$PeriodComparisonImpl> get copyWith =>
      __$$PeriodComparisonImplCopyWithImpl<_$PeriodComparisonImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PeriodComparisonImplToJson(
      this,
    );
  }
}

abstract class _PeriodComparison implements PeriodComparison {
  const factory _PeriodComparison(
      {required final String metric,
      required final double currentValue,
      required final double previousValue,
      required final double changePercent,
      required final bool isImprovement}) = _$PeriodComparisonImpl;

  factory _PeriodComparison.fromJson(Map<String, dynamic> json) =
      _$PeriodComparisonImpl.fromJson;

  @override
  String get metric;
  @override
  double get currentValue;
  @override
  double get previousValue;
  @override
  double get changePercent;
  @override
  bool get isImprovement;

  /// Create a copy of PeriodComparison
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PeriodComparisonImplCopyWith<_$PeriodComparisonImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
