// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GoalImpl _$$GoalImplFromJson(Map<String, dynamic> json) => _$GoalImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      metric: json['metric'] as String,
      comparison: $enumDecode(_$GoalComparisonEnumMap, json['comparison']),
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      period: $enumDecode(_$GoalPeriodEnumMap, json['period']),
      dogId: json['dogId'] as String?,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$GoalImplToJson(_$GoalImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'metric': instance.metric,
      'comparison': _$GoalComparisonEnumMap[instance.comparison]!,
      'targetValue': instance.targetValue,
      'currentValue': instance.currentValue,
      'period': _$GoalPeriodEnumMap[instance.period]!,
      'dogId': instance.dogId,
      'deadline': instance.deadline?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$GoalComparisonEnumMap = {
  GoalComparison.lessThan: 'less_than',
  GoalComparison.greaterThan: 'greater_than',
  GoalComparison.equal: 'equal',
};

const _$GoalPeriodEnumMap = {
  GoalPeriod.daily: 'daily',
  GoalPeriod.weekly: 'weekly',
  GoalPeriod.monthly: 'monthly',
};
