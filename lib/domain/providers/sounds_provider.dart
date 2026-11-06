import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/conn_trace.dart';
import '../../data/datasources/sounds_api.dart';
import '../../data/models/sound_catalog.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';
import 'settings_provider.dart';

class SoundsState {
  final List<SoundSlot> catalog;
  final bool loading;

  /// Sound id currently uploading / resetting, with 0..1 progress.
  final String? busyId;
  final double progress;

  /// True while "reset all" is in flight.
  final bool resettingAll;
  final String? error;

  /// Catalog came from the server (relay `sounds` setting / robot GET /sounds).
  final bool fromServer;

  /// Per-sound factory restore is a robot-local feature; the relay only
  /// resets the whole library.
  final bool canRestoreOne;

  /// Dog the catalog was loaded for (relay routes are dog-scoped).
  final String? dogId;

  const SoundsState({
    this.catalog = kDefaultSoundCatalog,
    this.loading = false,
    this.busyId,
    this.progress = 0,
    this.resettingAll = false,
    this.error,
    this.fromServer = false,
    this.canRestoreOne = false,
    this.dogId,
  });

  SoundsState copyWith({
    List<SoundSlot>? catalog,
    bool? loading,
    String? busyId,
    bool clearBusy = false,
    double? progress,
    bool? resettingAll,
    String? error,
    bool clearError = false,
    bool? fromServer,
    bool? canRestoreOne,
    String? dogId,
  }) =>
      SoundsState(
        catalog: catalog ?? this.catalog,
        loading: loading ?? this.loading,
        busyId: clearBusy ? null : (busyId ?? this.busyId),
        progress: clearBusy ? 0 : (progress ?? this.progress),
        resettingAll: resettingAll ?? this.resettingAll,
        error: clearError ? null : (error ?? this.error),
        fromServer: fromServer ?? this.fromServer,
        canRestoreOne: canRestoreOne ?? this.canRestoreOne,
        dogId: dogId ?? this.dogId,
      );

  List<SoundSlot> byGroup(SoundGroup g) =>
      catalog.where((s) => s.group == g).toList();

  SoundSlot? byId(String id) {
    for (final s in catalog) {
      if (s.id == id) return s;
    }
    return null;
  }
}

final soundsProvider =
    StateNotifierProvider<SoundsNotifier, SoundsState>((ref) => SoundsNotifier(ref));

class SoundsNotifier extends StateNotifier<SoundsState> {
  final Ref _ref;
  SoundsNotifier(this._ref) : super(const SoundsState());

  bool get _isLocal => _ref.read(settingsProvider).localModeEnabled;
  String? get _token => _isLocal ? null : _ref.read(authProvider).token;

  /// Relay routes are dog-scoped; the robot ignores the id locally.
  String get _dogId => _ref.read(selectedDogProvider)?.id ?? state.dogId ?? '';

  /// Server catalog wins entirely; the default list is only a placeholder
  /// when neither the relay nor the robot answers.
  Future<void> load() async {
    if (state.loading) return;
    final dogId = _dogId;
    state = state.copyWith(
        loading: true, clearError: true, dogId: dogId, canRestoreOne: _isLocal);
    final server = await _ref
        .read(soundsApiProvider)
        .getCatalog(token: _token, dogId: dogId);
    if (!mounted) return;
    if (server == null) {
      state = state.copyWith(
          loading: false, fromServer: false, catalog: kDefaultSoundCatalog);
      return;
    }
    state = state.copyWith(catalog: server, loading: false, fromServer: true);
    connTrace('sounds',
        'catalog from ${_isLocal ? 'robot' : 'relay'}: ${server.length} ids (${server.where((s) => s.custom).length} custom)');
  }

  /// Replace one sound (or add a new id, e.g. an uploaded song). Returns
  /// null on success, else an error string.
  Future<String?> replace(
    SoundSlot slot,
    String filePath,
    String filename, {
    String? label,
  }) async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(busyId: slot.id, progress: 0, clearError: true);
    final err = await _ref.read(soundsApiProvider).replace(
          token: _token,
          dogId: _dogId,
          slot: slot,
          filePath: filePath,
          filename: filename,
          label: label,
          onProgress: (sent, total) {
            if (total > 0 && mounted) {
              state = state.copyWith(progress: sent / total);
            }
          },
        );
    if (!mounted) return err;
    if (err == null) {
      final exists = state.catalog.any((s) => s.id == slot.id);
      final updated = slot.copyWith(
          custom: true, updatedAt: DateTime.now(), label: label);
      state = state.copyWith(
        clearBusy: true,
        catalog: exists
            ? [for (final s in state.catalog) s.id == slot.id ? updated : s]
            : [...state.catalog, updated],
      );
      connTrace('sounds', 'replaced ${slot.id} with $filename');
    } else {
      state = state.copyWith(clearBusy: true, error: err);
    }
    return err;
  }

  /// Per-sound factory restore (robot-local only).
  Future<String?> resetOne(SoundSlot slot) async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(busyId: slot.id, clearError: true);
    final err = await _ref
        .read(soundsApiProvider)
        .resetOne(token: _token, dogId: _dogId, slot: slot);
    if (!mounted) return err;
    state = state.copyWith(
      clearBusy: true,
      error: err,
      catalog: err == null
          ? [
              for (final s in state.catalog)
                s.id == slot.id ? s.copyWith(custom: false) : s,
            ]
          : null,
    );
    return err;
  }

  /// Factory reset every sound (relay: builtins only, custom files removed).
  Future<String?> resetAll() async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(resettingAll: true, clearError: true);
    final err = await _ref
        .read(soundsApiProvider)
        .resetAll(token: _token, dogId: _dogId);
    if (!mounted) return err;
    state = state.copyWith(resettingAll: false, error: err);
    connTrace('sounds', 'reset all → ${err ?? 'ok'}');
    if (err == null) await load(); // relay returns the new library; re-read it
    return err;
  }
}
