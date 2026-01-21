import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dog_profile.dart';

/// Provider for list of dog profiles
final dogProfilesProvider =
    StateNotifierProvider<DogProfilesNotifier, List<DogProfile>>((ref) {
  return DogProfilesNotifier();
});

/// Provider for currently selected dog
final selectedDogProvider = StateProvider<DogProfile?>((ref) {
  final profiles = ref.watch(dogProfilesProvider);
  return profiles.isNotEmpty ? profiles.first : null;
});

/// Provider for a specific dog by ID
final dogProfileProvider = Provider.family<DogProfile?, String>((ref, id) {
  final profiles = ref.watch(dogProfilesProvider);
  try {
    return profiles.firstWhere((d) => d.id == id);
  } catch (_) {
    return null;
  }
});

/// Provider for dog daily summary
final dogDailySummaryProvider =
    Provider.family<DogDailySummary, String>((ref, dogId) {
  // In real implementation, fetch from API
  // For now, return mock data
  return DogDailySummary(
    dogId: dogId,
    date: DateTime.now(),
    treatCount: 5,
    sitCount: 3,
    barkCount: 12,
    goalProgress: 0.85,
    missionCount: 2,
    missionSuccessCount: 2,
  );
});

/// Dog profiles state notifier
class DogProfilesNotifier extends StateNotifier<List<DogProfile>> {
  DogProfilesNotifier() : super(_generateMockProfiles());

  /// Add a new dog profile
  void addProfile(DogProfile profile) {
    state = [...state, profile];
  }

  /// Update an existing dog profile
  void updateProfile(DogProfile profile) {
    state = state.map((p) {
      if (p.id == profile.id) return profile;
      return p;
    }).toList();
  }

  /// Remove a dog profile
  void removeProfile(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  /// Refresh profiles (would fetch from API in real implementation)
  Future<void> refresh() async {
    // In a real implementation, fetch from API
    // For now, just use mock data
  }
}

/// Generate mock dog profiles for testing
List<DogProfile> _generateMockProfiles() {
  return [
    DogProfile(
      id: 'dog_1',
      name: 'Max',
      breed: 'Golden Retriever',
      photoUrl: null,
      birthDate: DateTime(2022, 3, 15),
      weight: 32.5,
      notes: 'Loves treats and belly rubs',
      goals: ['goal_1', 'goal_2'],
      lastMissionId: 'mission_sit_training',
      createdAt: DateTime(2024, 1, 10),
    ),
    DogProfile(
      id: 'dog_2',
      name: 'Luna',
      breed: 'Border Collie',
      photoUrl: null,
      birthDate: DateTime(2021, 7, 22),
      weight: 18.0,
      notes: 'Very energetic, needs lots of exercise',
      goals: ['goal_3'],
      lastMissionId: 'mission_quiet_training',
      createdAt: DateTime(2024, 2, 5),
    ),
  ];
}

/// Extension to calculate dog age from birth date
extension DogProfileExtension on DogProfile {
  /// Calculate age in years and months
  String? get ageString {
    if (birthDate == null) return null;

    final now = DateTime.now();
    final years = now.year - birthDate!.year;
    final months = now.month - birthDate!.month;

    int totalYears = years;
    int totalMonths = months;

    if (totalMonths < 0) {
      totalYears--;
      totalMonths += 12;
    }

    if (totalYears > 0) {
      if (totalMonths > 0) {
        return '$totalYears ${totalYears == 1 ? 'year' : 'years'}, $totalMonths ${totalMonths == 1 ? 'month' : 'months'}';
      }
      return '$totalYears ${totalYears == 1 ? 'year' : 'years'}';
    }
    return '$totalMonths ${totalMonths == 1 ? 'month' : 'months'}';
  }

  /// Get short age string (e.g., "3 years")
  String? get shortAgeString {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }

    if (years < 1) {
      final months = now.difference(birthDate!).inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    return '$years ${years == 1 ? 'year' : 'years'}';
  }
}
