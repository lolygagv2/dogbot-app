import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal.freezed.dart';
part 'goal.g.dart';

/// Comparison type for goal targets
@JsonEnum(fieldRename: FieldRename.snake)
enum GoalComparison {
  lessThan,
  greaterThan,
  equal,
}

/// Time period for goal measurement
@JsonEnum(fieldRename: FieldRename.snake)
enum GoalPeriod {
  daily,
  weekly,
  monthly,
}

/// A training goal for a dog
@freezed
class Goal with _$Goal {
  const Goal._();

  const factory Goal({
    required String id,
    required String title,
    required String metric,
    required GoalComparison comparison,
    required double targetValue,
    required double currentValue,
    required GoalPeriod period,
    String? dogId,
    DateTime? deadline,
    DateTime? createdAt,
    @Default(true) bool isActive,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  /// Create from API response
  factory Goal.fromApiResponse(Map<String, dynamic> data) {
    return Goal(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      metric: data['metric'] as String? ?? '',
      comparison: _parseComparison(data['comparison'] as String? ?? 'less_than'),
      targetValue: (data['target_value'] as num?)?.toDouble() ??
          (data['targetValue'] as num?)?.toDouble() ?? 0.0,
      currentValue: (data['current_value'] as num?)?.toDouble() ??
          (data['currentValue'] as num?)?.toDouble() ?? 0.0,
      period: _parsePeriod(data['period'] as String? ?? 'daily'),
      dogId: data['dog_id'] as String? ?? data['dogId'] as String?,
      deadline: data['deadline'] != null
          ? DateTime.parse(data['deadline'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
      isActive: data['is_active'] as bool? ?? data['isActive'] as bool? ?? true,
    );
  }

  /// Calculate progress as percentage (0.0 to 1.0)
  double get progress {
    if (targetValue == 0) return 0.0;

    switch (comparison) {
      case GoalComparison.lessThan:
        // Progress increases as we get closer to target from above
        if (currentValue <= targetValue) return 1.0;
        // Assume starting point is 2x target
        final startPoint = targetValue * 2;
        return 1.0 - ((currentValue - targetValue) / (startPoint - targetValue)).clamp(0.0, 1.0);
      case GoalComparison.greaterThan:
        // Progress increases as we approach/exceed target
        return (currentValue / targetValue).clamp(0.0, 1.0);
      case GoalComparison.equal:
        // Progress is 1.0 if equal, decreases with distance
        final diff = (currentValue - targetValue).abs();
        return (1.0 - (diff / targetValue)).clamp(0.0, 1.0);
    }
  }

  /// Check if goal is achieved
  bool get isAchieved {
    switch (comparison) {
      case GoalComparison.lessThan:
        return currentValue < targetValue;
      case GoalComparison.greaterThan:
        return currentValue > targetValue;
      case GoalComparison.equal:
        return currentValue == targetValue;
    }
  }

  /// Get human-readable goal description
  String get description {
    final compStr = switch (comparison) {
      GoalComparison.lessThan => '<',
      GoalComparison.greaterThan => '>',
      GoalComparison.equal => '=',
    };
    final periodStr = switch (period) {
      GoalPeriod.daily => '/day',
      GoalPeriod.weekly => '/week',
      GoalPeriod.monthly => '/month',
    };
    return '$compStr ${targetValue.toInt()} $periodStr';
  }
}

GoalComparison _parseComparison(String value) {
  return switch (value) {
    'less_than' || 'lessThan' => GoalComparison.lessThan,
    'greater_than' || 'greaterThan' => GoalComparison.greaterThan,
    'equal' => GoalComparison.equal,
    _ => GoalComparison.lessThan,
  };
}

GoalPeriod _parsePeriod(String value) {
  return switch (value) {
    'daily' => GoalPeriod.daily,
    'weekly' => GoalPeriod.weekly,
    'monthly' => GoalPeriod.monthly,
    _ => GoalPeriod.daily,
  };
}
