import 'package:freezed_annotation/freezed_annotation.dart';

part 'dog_profile.freezed.dart';
part 'dog_profile.g.dart';

/// A dog profile with information and stats
@freezed
class DogProfile with _$DogProfile {
  const factory DogProfile({
    required String id,
    required String name,
    String? breed,
    String? photoUrl,
    DateTime? birthDate,
    double? weight,
    String? notes,
    @Default([]) List<String> goals,
    String? lastMissionId,
    DateTime? createdAt,
  }) = _DogProfile;

  factory DogProfile.fromJson(Map<String, dynamic> json) =>
      _$DogProfileFromJson(json);

  /// Create from API response
  factory DogProfile.fromApiResponse(Map<String, dynamic> data) {
    return DogProfile(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown',
      breed: data['breed'] as String?,
      photoUrl: data['photo_url'] as String? ?? data['photoUrl'] as String?,
      birthDate: data['birth_date'] != null
          ? DateTime.parse(data['birth_date'] as String)
          : data['birthDate'] != null
              ? DateTime.parse(data['birthDate'] as String)
              : null,
      weight: (data['weight'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      goals: (data['goals'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMissionId: data['last_mission_id'] as String? ??
          data['lastMissionId'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : data['createdAt'] != null
              ? DateTime.parse(data['createdAt'] as String)
              : null,
    );
  }
}

/// Summary stats for a dog on a given day
@freezed
class DogDailySummary with _$DogDailySummary {
  const factory DogDailySummary({
    required String dogId,
    required DateTime date,
    @Default(0) int treatCount,
    @Default(0) int sitCount,
    @Default(0) int barkCount,
    @Default(0.0) double goalProgress,
    @Default(0) int missionCount,
    @Default(0) int missionSuccessCount,
  }) = _DogDailySummary;

  factory DogDailySummary.fromJson(Map<String, dynamic> json) =>
      _$DogDailySummaryFromJson(json);
}
