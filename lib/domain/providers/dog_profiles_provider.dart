import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/dog_profile.dart';

const String _dogsKey = 'dog_profiles';
const String _selectedDogKey = 'selected_dog_id';

/// Provider for list of dog profiles
final dogProfilesProvider =
    StateNotifierProvider<DogProfilesNotifier, List<DogProfile>>((ref) {
  return DogProfilesNotifier(ref);
});

/// Provider for currently selected dog
final selectedDogProvider =
    StateNotifierProvider<SelectedDogNotifier, DogProfile?>((ref) {
  final profiles = ref.watch(dogProfilesProvider);
  return SelectedDogNotifier(profiles);
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

/// Dog profiles state notifier with persistence
class DogProfilesNotifier extends StateNotifier<List<DogProfile>> {
  final Ref _ref;
  SharedPreferences? _prefs;

  DogProfilesNotifier(this._ref) : super([]) {
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    _prefs = await SharedPreferences.getInstance();
    final json = _prefs?.getString(_dogsKey);

    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json);
        state = list.map((e) => DogProfile.fromJson(e as Map<String, dynamic>)).toList();
        print('DogProfiles: Loaded ${state.length} profiles from storage');
      } catch (e) {
        print('DogProfiles: Failed to load profiles: $e');
        state = [];
      }
    }
  }

  Future<void> _saveProfiles() async {
    _prefs ??= await SharedPreferences.getInstance();
    final json = jsonEncode(state.map((p) => p.toJson()).toList());
    await _prefs?.setString(_dogsKey, json);
    print('DogProfiles: Saved ${state.length} profiles');
  }

  /// Clear all profiles (used on logout)
  void clearState() {
    state = [];
  }

  /// Add a new dog profile (rejects duplicate names)
  Future<bool> addProfile(DogProfile profile) async {
    // Check for duplicate name (case-insensitive)
    final duplicate = state.any(
      (p) => p.name.toLowerCase() == profile.name.toLowerCase(),
    );
    if (duplicate) {
      print('DogProfiles: Rejected duplicate name "${profile.name}"');
      return false;
    }

    state = [...state, profile];
    await _saveProfiles();
    return true;
  }

  /// Update an existing dog profile
  Future<void> updateProfile(DogProfile profile) async {
    state = state.map((p) {
      if (p.id == profile.id) return profile;
      return p;
    }).toList();
    await _saveProfiles();
  }

  /// Remove a dog profile
  Future<void> removeProfile(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _saveProfiles();

    // Clear selection if deleted dog was selected
    final selected = _ref.read(selectedDogProvider);
    if (selected != null && selected.id == id) {
      _ref.read(selectedDogProvider.notifier).clearState();
    }
  }

  /// Update profile photo path
  Future<void> updateProfilePhoto(String dogId, String photoPath) async {
    state = state.map((p) {
      if (p.id == dogId) {
        return p.copyWith(localPhotoPath: photoPath);
      }
      return p;
    }).toList();
    await _saveProfiles();
  }
}

/// Selected dog notifier with persistence
class SelectedDogNotifier extends StateNotifier<DogProfile?> {
  final List<DogProfile> _profiles;
  SharedPreferences? _prefs;

  SelectedDogNotifier(this._profiles) : super(null) {
    _loadSelectedDog();
  }

  Future<void> _loadSelectedDog() async {
    _prefs = await SharedPreferences.getInstance();
    final selectedId = _prefs?.getString(_selectedDogKey);

    if (selectedId != null && _profiles.isNotEmpty) {
      try {
        state = _profiles.firstWhere((d) => d.id == selectedId);
      } catch (_) {
        state = _profiles.isNotEmpty ? _profiles.first : null;
      }
    } else if (_profiles.isNotEmpty) {
      state = _profiles.first;
    }
  }

  /// Clear selection (used on logout)
  void clearState() {
    state = null;
  }

  Future<void> selectDog(DogProfile dog) async {
    state = dog;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_selectedDogKey, dog.id);
  }
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

  /// Get color for display
  Color get displayColor {
    switch (color) {
      case DogColor.black:
        return const Color(0xFF333333);
      case DogColor.yellow:
        return const Color(0xFFD4A574);
      case DogColor.brown:
        return const Color(0xFF8B4513);
      case DogColor.white:
        return const Color(0xFFF5F5F5);
      case DogColor.mixed:
        return const Color(0xFF888888);
    }
  }
}
