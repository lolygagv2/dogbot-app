import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/dog_profile.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';

// Build 32: Dogs scoped by user email to fix security issue (Issue 6)
// Keys are now functions that include user scope
String _dogsKeyForUser(String? email) => 'dog_profiles_${email ?? 'anonymous'}';
String _selectedDogKeyForUser(String? email) => 'selected_dog_${email ?? 'anonymous'}';

/// Provider for list of dog profiles
final dogProfilesProvider =
    StateNotifierProvider<DogProfilesNotifier, List<DogProfile>>((ref) {
  return DogProfilesNotifier(ref);
});

/// Provider for currently selected dog (Build 32: scoped by user)
final selectedDogProvider =
    StateNotifierProvider<SelectedDogNotifier, DogProfile?>((ref) {
  final profiles = ref.watch(dogProfilesProvider);
  final userEmail = ref.watch(authProvider).email;
  return SelectedDogNotifier(profiles, userEmail: userEmail);
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

/// Dog profiles state notifier with persistence (Build 32: scoped by user)
class DogProfilesNotifier extends StateNotifier<List<DogProfile>> {
  final Ref _ref;
  SharedPreferences? _prefs;
  String? _currentUserEmail;

  DogProfilesNotifier(this._ref) : super([]) {
    _loadProfiles().then((_) {
      // After profiles are loaded, sync to robot if already connected
      // Check both relay connection AND local connection
      final isConnected = _ref.read(connectionProvider).isConnected ||
          _ref.read(localConnectionProvider).isConnected;
      if (isConnected && state.isNotEmpty) {
        _syncProfilesToRobot();
      }
    });
    // Also sync when relay connection comes online (reconnect, etc.)
    _ref.listen<ConnectionState>(connectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true && state.isNotEmpty) {
        _syncProfilesToRobot();
      }
    });
    // Also sync when local connection comes online
    _ref.listen<LocalConnectionData>(localConnectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true && state.isNotEmpty) {
        _syncProfilesToRobot();
      }
    });
  }

  /// Get current user's email for scoped storage
  String? get _userEmail => _ref.read(authProvider).email;

  Future<void> _loadProfiles() async {
    _prefs = await SharedPreferences.getInstance();
    _currentUserEmail = _userEmail;
    final key = _dogsKeyForUser(_currentUserEmail);
    final json = _prefs?.getString(key);

    print('DogProfiles: Loading for user $_currentUserEmail (key: $key)');

    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json);
        state = list.map((e) => DogProfile.fromJson(e as Map<String, dynamic>)).toList();
        print('DogProfiles: Loaded ${state.length} profiles from storage');
      } catch (e) {
        print('DogProfiles: Failed to load profiles: $e');
        state = [];
      }
    } else {
      state = [];
      print('DogProfiles: No profiles found for this user');
    }
  }

  Future<void> _saveProfiles() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Build 32 fix: Always use fresh email from auth, not cached value
    // This prevents saving to wrong key if auth loaded after dogs
    final email = _userEmail ?? _currentUserEmail;
    final key = _dogsKeyForUser(email);
    final json = jsonEncode(state.map((p) => p.toJson()).toList());
    await _prefs?.setString(key, json);
    print('DogProfiles: Saved ${state.length} profiles for user $email');
  }

  /// Reload profiles for current user (call after login/logout)
  Future<void> reloadForCurrentUser() async {
    print('DogProfiles: Reloading for current user');
    await _loadProfiles();
  }

  /// A1: Hydrate dog profiles from the relay on login / fresh install.
  /// Strategy: relay is the source of truth for *existence*; per-record the
  /// newer `updatedAt` wins. Local-only entries (no matching id on relay) are
  /// uploaded to the relay so future devices get them.
  /// Skipped silently in local mode or when no token is available.
  Future<void> hydrateFromRelay() async {
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (isLocal || token == null) {
      print('DogProfiles: hydrateFromRelay skipped (local=$isLocal, hasToken=${token != null})');
      return;
    }

    try {
      final api = _ref.read(robotApiProvider);
      final remote = await api.getDogs(token);
      print('DogProfiles: hydrateFromRelay fetched ${remote.length} from relay (local=${state.length})');

      // Make sure we have the latest local copy from disk for this user.
      await _loadProfiles();

      final byId = <String, DogProfile>{
        for (final p in state) p.id: p,
      };
      for (final r in remote) {
        final local = byId[r.id];
        if (local == null) {
          // Relay knows about a dog we don't have locally — adopt it.
          byId[r.id] = r;
        } else {
          // Conflict: take whichever has the newer updatedAt. Null updatedAt
          // is treated as oldest, so a record with a real timestamp wins.
          final lu = local.updatedAt?.millisecondsSinceEpoch ?? 0;
          final ru = r.updatedAt?.millisecondsSinceEpoch ?? 0;
          if (ru > lu) {
            // Preserve local-only fields (photo cache) when remote is authoritative.
            byId[r.id] = r.copyWith(
              localPhotoPath: local.localPhotoPath,
              photoVersion: local.photoVersion,
            );
          }
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));
      state = merged;
      await _saveProfiles();

      // Push any local-only profiles up to the relay so future installs
      // (and the other device that didn't have them) can see them.
      final remoteIds = remote.map((r) => r.id).toSet();
      for (final p in state) {
        if (!remoteIds.contains(p.id)) {
          try {
            final api = _ref.read(robotApiProvider);
            await api.createDog(p.toJson(), token);
            print('DogProfiles: Backfilled local-only profile "${p.name}" to relay');
          } catch (e) {
            print('DogProfiles: Failed to backfill "${p.name}": $e');
          }
        }
      }

      // If we're already connected to a robot, push the merged list.
      final isConnected = _ref.read(connectionProvider).isConnected ||
          _ref.read(localConnectionProvider).isConnected;
      if (isConnected && state.isNotEmpty) {
        _syncProfilesToRobot();
      }
    } catch (e) {
      print('DogProfiles: hydrateFromRelay error: $e');
    }
  }

  /// Clear all profiles (used on logout)
  void clearState() {
    state = [];
  }

  /// Push all profiles to robot via reload_dogs command.
  /// Robot uses this to update its profile manager and dog tracker
  /// without needing to fetch from the relay.
  void _syncProfilesToRobot() {
    try {
      final ws = _ref.read(websocketClientProvider);
      final profiles = state.map((p) => {
        'name': p.name,
        if (p.arucoMarkerId != null) 'aruco_id': p.arucoMarkerId,
        'color': p.color.value,
        'id': p.id,
        if (p.breed != null) 'breed': p.breed,
      }).toList();

      ws.sendCommand('reload_dogs', {'profiles': profiles});
      print('DogProfiles: Synced ${profiles.length} profiles to robot:');
      for (final p in profiles) {
        print('  - ${p['name']} (aruco=${p['aruco_id'] ?? 'none'}, color=${p['color']})');
      }

      // Build 91 (C3 app-side): re-assert the currently-selected dog so the
      // robot's "active dog" cache survives reconnects / app restarts.
      final selected = _ref.read(selectedDogProvider);
      if (selected != null) {
        ws.sendCommand('select_dog', {
          'dog_id': selected.id,
          'dog_name': selected.name,
        });
      }
    } catch (e) {
      print('DogProfiles: Failed to sync profiles to robot: $e');
    }
  }

  /// Lowest unused ArUco ID in [start, end] (inclusive). Used when adding a
  /// new dog so each marker on the floor decodes to a unique profile. The
  /// robot decodes DICT_4X4_1000 so we cap at 999.
  ///
  /// App-side allocation is fine for single-user single-device; if two
  /// devices add at the exact same time they'd race, but the relay's
  /// per-user unique-by-name guard catches duplicates downstream.
  int nextFreeArucoId({int start = 0, int end = 999}) {
    final used = <int>{
      for (final p in state)
        if (p.arucoMarkerId != null) p.arucoMarkerId!,
    };
    for (var id = start; id <= end; id++) {
      if (!used.contains(id)) return id;
    }
    return end; // dictionary full — should be unreachable in practice
  }

  /// Add a new dog profile (rejects duplicate names)
  /// Saves locally, syncs to relay server, and tells robot to reload.
  Future<bool> addProfile(DogProfile profile) async {
    // Check for duplicate name (case-insensitive)
    final duplicate = state.any(
      (p) => p.name.toLowerCase() == profile.name.toLowerCase(),
    );
    if (duplicate) {
      print('DogProfiles: Rejected duplicate name "${profile.name}"');
      return false;
    }

    // A1: stamp updatedAt for merge precedence
    final stamped = profile.updatedAt == null
        ? profile.copyWith(updatedAt: DateTime.now().toUtc())
        : profile;
    state = [...state, stamped];
    await _saveProfiles();

    // Sync to relay server (skip in local mode — no relay API)
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (!isLocal && token != null) {
      try {
        final api = _ref.read(robotApiProvider);
        final success = await api.createDog(stamped.toJson(), token);
        print('DogProfiles: Relay sync ${success ? 'succeeded' : 'failed'} for "${stamped.name}"');
      } catch (e) {
        print('DogProfiles: Relay sync error for "${stamped.name}": $e');
      }
    }

    // Push all profiles to robot (includes the new one)
    _syncProfilesToRobot();

    return true;
  }

  /// Update an existing dog profile
  Future<void> updateProfile(DogProfile profile) async {
    // A1: bump updatedAt on every mutation
    final stamped = profile.copyWith(updatedAt: DateTime.now().toUtc());
    state = state.map((p) {
      if (p.id == stamped.id) return stamped;
      return p;
    }).toList();
    await _saveProfiles();

    // Sync update to relay (skip in local mode — no relay API)
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (!isLocal && token != null) {
      try {
        final api = _ref.read(robotApiProvider);
        await api.createDog(stamped.toJson(), token);
        print('DogProfiles: Relay update sync sent for "${stamped.name}"');
      } catch (e) {
        print('DogProfiles: Relay update sync error: $e');
      }
    }

    _syncProfilesToRobot();
  }

  /// Remove a dog profile (Build 32: also sends delete_dog to robot)
  Future<void> removeProfile(String id) async {
    // Attempt server-side delete (skip in local mode — no relay API)
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (!isLocal && token != null) {
      try {
        final api = _ref.read(robotApiProvider);
        final success = await api.deleteDog(id, token);
        if (!success) {
          print('DogProfiles: Server delete failed for $id, removing locally');
        }
      } catch (e) {
        print('DogProfiles: Server delete error for $id: $e');
      }
    }

    // Build 32: Send delete_dog command to robot to clean up voice files
    try {
      final ws = _ref.read(websocketClientProvider);
      ws.sendCommand('delete_dog', {'dog_id': id});
      print('DogProfiles: Sent delete_dog command to robot for $id');
    } catch (e) {
      print('DogProfiles: Failed to send delete_dog to robot: $e');
    }

    state = state.where((p) => p.id != id).toList();
    await _saveProfiles();

    // Sync updated profile list to robot (minus the deleted one)
    _syncProfilesToRobot();

    // Clear selection if deleted dog was selected
    final selected = _ref.read(selectedDogProvider);
    if (selected != null && selected.id == id) {
      _ref.read(selectedDogProvider.notifier).clearState();
    }
  }

  /// Update profile photo path (increments photoVersion for cache-busting)
  Future<void> updateProfilePhoto(String dogId, String photoPath) async {
    print('[PHOTO] updateProfilePhoto called: dogId=$dogId, path=$photoPath');
    print('[PHOTO] Current profiles: ${state.map((p) => '${p.id}:${p.name}').toList()}');

    final beforeProfile = state.firstWhere((p) => p.id == dogId, orElse: () => throw Exception('Dog not found'));
    print('[PHOTO] Before update: localPhotoPath=${beforeProfile.localPhotoPath}, photoVersion=${beforeProfile.photoVersion}');

    state = state.map((p) {
      if (p.id == dogId) {
        print('[PHOTO] Updating profile for ${p.name}, incrementing photoVersion');
        // Increment photoVersion to force image cache refresh (Build 32 fix)
        return p.copyWith(
          localPhotoPath: photoPath,
          photoVersion: p.photoVersion + 1,
        );
      }
      return p;
    }).toList();

    final afterProfile = state.firstWhere((p) => p.id == dogId);
    print('[PHOTO] After update: localPhotoPath=${afterProfile.localPhotoPath}, photoVersion=${afterProfile.photoVersion}');

    await _saveProfiles();
    print('[PHOTO] Profiles saved to SharedPreferences');
  }
}

/// Selected dog notifier with persistence (Build 32: scoped by user)
class SelectedDogNotifier extends StateNotifier<DogProfile?> {
  final List<DogProfile> _profiles;
  SharedPreferences? _prefs;
  String? _userEmail;

  SelectedDogNotifier(this._profiles, {String? userEmail}) : _userEmail = userEmail, super(null) {
    _loadSelectedDog();
  }

  Future<void> _loadSelectedDog() async {
    _prefs = await SharedPreferences.getInstance();
    final key = _selectedDogKeyForUser(_userEmail);
    final selectedId = _prefs?.getString(key);

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
    final key = _selectedDogKeyForUser(_userEmail);
    await _prefs?.setString(key, dog.id);
    // Build 91 (C3 app-side): tell the robot which dog is now "active"
    // so autonomous voice playback (coach rewards, Silent Guardian, Xbox
    // controller buttons) uses this dog's per-dog voice files when no
    // ArUco is visible to identify the dog directly.
    try {
      WebSocketClient.instance.sendCommand('select_dog', {
        'dog_id': dog.id,
        'dog_name': dog.name,
      });
    } catch (_) {/* WS not connected — robot will pick this up on next connect */}
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
