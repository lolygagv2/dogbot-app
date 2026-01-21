// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyStatsImpl _$$DailyStatsImplFromJson(Map<String, dynamic> json) =>
    _$DailyStatsImpl(
      date: DateTime.parse(json['date'] as String),
      barkCount: (json['barkCount'] as num?)?.toInt() ?? 0,
      sitCount: (json['sitCount'] as num?)?.toInt() ?? 0,
      treatCount: (json['treatCount'] as num?)?.toInt() ?? 0,
      missionCount: (json['missionCount'] as num?)?.toInt() ?? 0,
      missionSuccessCount: (json['missionSuccessCount'] as num?)?.toInt() ?? 0,
      totalActiveTime: json['totalActiveTime'] == null
          ? Duration.zero
          : Duration(microseconds: (json['totalActiveTime'] as num).toInt()),
    );

Map<String, dynamic> _$$DailyStatsImplToJson(_$DailyStatsImpl instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'barkCount': instance.barkCount,
      'sitCount': instance.sitCount,
      'treatCount': instance.treatCount,
      'missionCount': instance.missionCount,
      'missionSuccessCount': instance.missionSuccessCount,
      'totalActiveTime': instance.totalActiveTime.inMicroseconds,
    };

_$AnalyticsDataImpl _$$AnalyticsDataImplFromJson(Map<String, dynamic> json) =>
    _$AnalyticsDataImpl(
      dogId: json['dogId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      dailyStats: (json['dailyStats'] as List<dynamic>?)
              ?.map((e) => DailyStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      behaviorDistribution:
          (json['behaviorDistribution'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
      missionSuccessRates:
          (json['missionSuccessRates'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toDouble()),
              ) ??
              const {},
    );

Map<String, dynamic> _$$AnalyticsDataImplToJson(_$AnalyticsDataImpl instance) =>
    <String, dynamic>{
      'dogId': instance.dogId,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'dailyStats': instance.dailyStats,
      'behaviorDistribution': instance.behaviorDistribution,
      'missionSuccessRates': instance.missionSuccessRates,
    };

_$PeriodComparisonImpl _$$PeriodComparisonImplFromJson(
        Map<String, dynamic> json) =>
    _$PeriodComparisonImpl(
      metric: json['metric'] as String,
      currentValue: (json['currentValue'] as num).toDouble(),
      previousValue: (json['previousValue'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      isImprovement: json['isImprovement'] as bool,
    );

Map<String, dynamic> _$$PeriodComparisonImplToJson(
        _$PeriodComparisonImpl instance) =>
    <String, dynamic>{
      'metric': instance.metric,
      'currentValue': instance.currentValue,
      'previousValue': instance.previousValue,
      'changePercent': instance.changePercent,
      'isImprovement': instance.isImprovement,
    };
