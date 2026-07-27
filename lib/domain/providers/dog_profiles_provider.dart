import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/activity_aggregation.dart';
import '../../data/models/dog_profile.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';
import 'notifications_provider.dart';
import 'settings_provider.dart';

// Build 32: Dogs scoped by user email to fix security issue (Issue 6)
// Keys are now functions that include user scope.
// Build 125: in LOCAL mode there is no authenticated user (email is null), and
// a stale cloud JWT could otherwise shift the scope between save and load —
// stranding the just-added dog. So local mode uses a fixed 'local' scope that
// is stable across restarts regardless of any leftover auth state.
String _dogsKeyForScope(String scope) => 'dog_profiles_$scope';
String _selectedDogKeyForScope(String scope) => 'selected_dog_$scope';

/// Provider for list of dog profiles
final dogProfilesProvider =
    StateNotifierProvider<DogProfilesNotifier, List<DogProfile>>((ref) {
  return DogProfilesNotifier(ref);
});

/// Provider for currently selected dog (Build 32: scoped by user)
final selectedDogProvider =
    StateNotifierProvider<SelectedDogNotifier, DogProfile?>((ref) {
  final profiles = ref.watch(dogProfilesProvider);
  final localMode = ref.watch(settingsProvider).localModeEnabled;
  final userEmail = ref.watch(authProvider).email;
  final scope = localMode ? 'local' : (userEmail ?? 'anonymous');
  return SelectedDogNotifier(profiles, scope: scope);
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

/// Provider for dog daily summary — REAL data, derived from today's activity
/// events (live WS + relay history). No more hardcoded 5/3/12 baseline.
final dogDailySummaryProvider =
    Provider.family<DogDailySummary, String>((ref, dogId) {
  final events = ref.watch(notificationsProvider);
  return summarizeDay(events, dogId: dogId, day: DateTime.now());
});

/// Dog profiles state notifier with persistence (Build 32: scoped by user)
class DogProfilesNotifier extends StateNotifier<List<DogProfile>> {
  final Ref _ref;
  SharedPreferences? _prefs;

  /// A-PROFILE: scope the in-memory list was loaded from. _scope is computed
  /// lazily at save time, so an auth/local-mode flip between load and save
  /// used to write the OLD scope's list into the NEW scope's bucket —
  /// overwriting (destroying) whatever was saved there. _saveProfiles refuses
  /// the write when the two disagree.
  String? _loadedScope;

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
    // Also sync when local connection comes online.
    // Build 125: reload first — the provider may have been built before local
    // mode was set / connection resolved, so its in-memory list could be from
    // the wrong scope. reloadForCurrentUser() re-reads the correct ('local')
    // bucket, THEN we push to the robot.
    _ref.listen<LocalConnectionData>(localConnectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        reloadForCurrentUser().then((_) {
          if (state.isNotEmpty) _syncProfilesToRobot();
        });
      }
    });
    // A-PROFILE: the scope inputs can change long after construction (silent
    // re-auth flips localModeEnabled, login/logout changes the email). Without
    // these listeners the list stays loaded from the OLD scope and looks
    // empty/wrong until a local connect happens — which in cloud mode never
    // does. Reload whenever the effective scope shifts.
    _ref.listen<bool>(
        settingsProvider.select((s) => s.localModeEnabled), (prev, next) {
      if (prev != next) reloadForCurrentUser();
    });
    _ref.listen<String?>(authProvider.select((a) => a.email), (prev, next) {
      if (prev != next) reloadForCurrentUser();
    });
  }

  /// Get current user's email for scoped storage
  String? get _userEmail => _ref.read(authProvider).email;

  /// Build 125: storage scope. In local mode there's no auth identity, so use a
  /// fixed 'local' scope that's stable across restarts (persisted via settings).
  /// In cloud mode, scope by user email (unchanged behavior).
  String get _scope {
    if (_ref.read(settingsProvider).localModeEnabled) return 'local';
    return _userEmail ?? 'anonymous';
  }

  Future<void> _loadProfiles() async {
    _prefs = await SharedPreferences.getInstance();
    final scope = _scope;
    _loadedScope = scope;
    final key = _dogsKeyForScope(scope);
    var json = _prefs?.getString(key);

    // Build 125 migration: earlier local builds saved dogs under the
    // 'anonymous' scope. If we're now on 'local' and it's empty but 'anonymous'
    // has data, adopt it so existing local users don't lose their dogs.
    if ((json == null || json.isEmpty) && scope == 'local') {
      final legacy = _prefs?.getString(_dogsKeyForScope('anonymous'));
      if (legacy != null && legacy.isNotEmpty) {
        json = legacy;
        await _prefs?.setString(key, legacy);
        print('DogProfiles: migrated anonymous → local scope');
      }
    }

    print('DogProfiles: Loading for scope "$scope" (key: $key)');

    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json);
        final loaded =
            list.map((e) => DogProfile.fromJson(e as Map<String, dynamic>)).toList();
        // Heal duplicates persisted by earlier builds (relay id-mint bug).
        final healed = dedupeByName(loaded);
        if (healed.length != loaded.length) {
          connTrace('dogprofiles-load-dedupe',
              'collapsed ${loaded.length}→${healed.length} same-name profiles');
        }
        state = healed;
        print('DogProfiles: Loaded ${state.length} profiles from storage');
      } catch (e) {
        print('DogProfiles: Failed to load profiles: $e');
        state = [];
      }
    } else {
      state = [];
      print('DogProfiles: No profiles found for this scope');
    }
  }

  Future<void> _saveProfiles() async {
    _prefs ??= await SharedPreferences.getInstance();
    final scope = _scope;
    if (_loadedScope != scope) {
      // Scope shifted between load and save. Writing now would replace the
      // new scope's bucket with a list that belongs to the old scope —
      // permanent, unrecoverable profile loss in local mode. Reload instead;
      // the scope-change listeners normally make this window unreachable.
      connTrace('dogprofiles-save-refused',
          'loaded scope "$_loadedScope" != current "$scope" — reloading');
      await _loadProfiles();
      return;
    }
    final key = _dogsKeyForScope(scope);
    final json = jsonEncode(state.map((p) => p.toJson()).toList());
    await _prefs?.setString(key, json);
    print('DogProfiles: Saved ${state.length} profiles (key: $key)');
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
    // A-PROFILE: gate on the MODE flag too, not just an established local
    // connection — with local mode enabled but not yet connected, this used
    // to merge cloud dogs into (and save them under) the 'local' bucket.
    final isLocal = _ref.read(settingsProvider).localModeEnabled ||
        _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (isLocal || token == null) {
      print('DogProfiles: hydrateFromRelay skipped (local=$isLocal, hasToken=${token != null})');
      return;
    }

    try {
      final api = _ref.read(robotApiProvider);
      final remote = await api.getDogs(token);
      print('DogProfiles: hydrateFromRelay fetched ${remote.length} from relay (local=${state.length})');

      // Make sure we have the latest local copy from disk for this user
      // (_loadProfiles also heals persisted same-name duplicates).
      await _loadProfiles();

      final result = mergeRelayDogs(state, remote);
      state = result.merged;
      await _saveProfiles();

      // Push any local-only profiles up to the relay so future installs
      // (and the other device that didn't have them) can see them.
      for (final p in state) {
        if (!result.relayKnownIds.contains(p.id)) {
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

  /// Merge relay dogs into the local list. Remote records whose id we don't
  /// recognize are matched by name instead of adopted blindly.
  ///
  /// History: POST /dogs used to mint its own ids instead of honoring ours,
  /// so id-only merging re-adopted the same dog on every login — one new
  /// replica per logout/login cycle. The relay upserts by client id since
  /// 2026-07-27 (deployed), so no NEW minted-id rows appear — but rows minted
  /// before the fix may still live in the relay DB, and this name-match is
  /// what keeps collapsing them on every hydrate. Do not remove it until the
  /// relay's legacy rows are confirmed purged (relay has POST /api/dogs/merge
  /// for that). For healthy data it's a no-op: remote ids match ours.
  ///
  /// Matched dogs keep the LOCAL id (voice recordings, the robot's per-dog
  /// caches, and selection persistence all key on it); per-record the newer
  /// updatedAt wins, with null treated as oldest. `relayKnownIds` holds local
  /// ids the relay has a copy of under ANY id — those must not be backfilled,
  /// since re-POSTing them is what made the old relay mint yet another
  /// duplicate row each cycle (harmless now, but still redundant traffic).
  @visibleForTesting
  static ({List<DogProfile> merged, Set<String> relayKnownIds}) mergeRelayDogs(
      List<DogProfile> local, List<DogProfile> remote) {
    final byId = <String, DogProfile>{for (final p in local) p.id: p};
    final idByName = <String, String>{
      for (final p in local) p.name.toLowerCase(): p.id,
    };
    final relayKnownIds = <String>{};

    for (final r in remote) {
      final localId =
          byId.containsKey(r.id) ? r.id : idByName[r.name.toLowerCase()];
      if (localId == null) {
        // Genuinely new dog from another device — adopt it.
        byId[r.id] = r;
        idByName[r.name.toLowerCase()] = r.id;
        relayKnownIds.add(r.id);
        continue;
      }
      relayKnownIds.add(localId);
      final existing = byId[localId]!;
      final lu = existing.updatedAt?.millisecondsSinceEpoch ?? 0;
      final ru = r.updatedAt?.millisecondsSinceEpoch ?? 0;
      if (ru > lu) {
        // Preserve local-only fields (photo cache) when remote is authoritative.
        byId[localId] = r.copyWith(
          id: localId,
          createdAt: existing.createdAt ?? r.createdAt,
          localPhotoPath: existing.localPhotoPath,
          photoVersion: existing.photoVersion,
        );
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return (merged: merged, relayKnownIds: relayKnownIds);
  }

  /// Collapse same-name profiles into one. Names are unique per user
  /// (addProfile rejects duplicates case-insensitively), so same-name rows
  /// are replication artifacts from the relay minting its own dog ids.
  /// Keeps the earliest-created record's id (voice recordings and the
  /// robot's per-dog caches key on it) but adopts the newest record's
  /// editable fields.
  @visibleForTesting
  static List<DogProfile> dedupeByName(List<DogProfile> profiles) {
    final byName = <String, DogProfile>{};
    for (final p in profiles) {
      final key = p.name.toLowerCase();
      final kept = byName[key];
      if (kept == null) {
        byName[key] = p;
        continue;
      }
      // Null createdAt = legacy record = oldest.
      final keptCreated = kept.createdAt ?? DateTime(0);
      final pCreated = p.createdAt ?? DateTime(0);
      final keeper = keptCreated.isAfter(pCreated) ? p : kept;
      final keptUpdated = kept.updatedAt ?? DateTime(0);
      final pUpdated = p.updatedAt ?? DateTime(0);
      final newest = pUpdated.isAfter(keptUpdated) ? p : kept;
      byName[key] = newest.copyWith(
        id: keeper.id,
        createdAt: keeper.createdAt,
        localPhotoPath: kept.localPhotoPath ?? p.localPhotoPath,
        photoVersion:
            kept.photoVersion > p.photoVersion ? kept.photoVersion : p.photoVersion,
      );
    }
    return byName.values.toList();
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
        // WIMZ_Data_Architecture_Spec v0.3 `dog` table field names, sent
        // additively so the robot can reconcile these app-authoritative
        // fields (§2) into its dog table without a wire-contract break.
        // Timestamps are epoch ms per the spec; updated_at drives the
        // last-write-wins conflict rule.
        'dog_id': p.id,
        if (p.birthDate != null)
          'birthdate': p.birthDate!.millisecondsSinceEpoch,
        if (p.updatedAt != null)
          'updated_at': p.updatedAt!.millisecondsSinceEpoch,
        // v0.3: ArUco markers ride the existing qr_code_id / id_method='qr'
        // (spec changelog: the fleet's physical markers are ArUco, called
        // "QR" throughout). Omitted when no marker is assigned — nullable.
        if (p.arucoMarkerId != null) 'qr_code_id': '${p.arucoMarkerId}',
        if (p.arucoMarkerId != null) 'id_method': 'qr',
        // v0.3: app-authoritative reward config; robot defaults to 1 if null.
        'treats_per_reward': p.treatsPerReward,
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
  final String _scope;

  SelectedDogNotifier(this._profiles, {required String scope})
      : _scope = scope,
        super(null) {
    _loadSelectedDog();
  }

  Future<void> _loadSelectedDog() async {
    _prefs = await SharedPreferences.getInstance();
    final key = _selectedDogKeyForScope(_scope);
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
    final key = _selectedDogKeyForScope(_scope);
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
