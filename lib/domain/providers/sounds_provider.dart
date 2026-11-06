import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/conn_trace.dart';
import '../../data/datasources/sounds_api.dart';
import '../../data/models/sound_catalog.dart';
import 'auth_provider.dart';
import 'device_provider.dart';
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
  final bool fromRobot; // catalog came from GET /api/sounds

  const SoundsState({
    this.catalog = kDefaultSoundCatalog,
    this.loading = false,
    this.busyId,
    this.progress = 0,
    this.resettingAll = false,
    this.error,
    this.fromRobot = false,
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
    bool? fromRobot,
  }) =>
      SoundsState(
        catalog: catalog ?? this.catalog,
        loading: loading ?? this.loading,
        busyId: clearBusy ? null : (busyId ?? this.busyId),
        progress: clearBusy ? 0 : (progress ?? this.progress),
        resettingAll: resettingAll ?? this.resettingAll,
        error: clearError ? null : (error ?? this.error),
        fromRobot: fromRobot ?? this.fromRobot,
      );

  List<SoundSlot> byGroup(SoundGroup g) =>
      catalog.where((s) => s.group == g).toList();
}

final soundsProvider =
    StateNotifierProvider<SoundsNotifier, SoundsState>((ref) => SoundsNotifier(ref));

class SoundsNotifier extends StateNotifier<SoundsState> {
  final Ref _ref;
  SoundsNotifier(this._ref) : super(const SoundsState());

  String? get _token => _ref.read(settingsProvider).localModeEnabled
      ? null
      : _ref.read(authProvider).token;
  String get _deviceId => _ref.read(deviceIdProvider);

  /// Merge the robot's catalog over the default one (robot wins on id).
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    final robot = await _ref
        .read(soundsApiProvider)
        .getCatalog(token: _token, deviceId: _deviceId);
    if (!mounted) return;
    if (robot == null) {
      state = state.copyWith(loading: false, fromRobot: false);
      return;
    }
    final byId = {for (final s in kDefaultSoundCatalog) s.id: s};
    for (final s in robot) {
      byId[s.id] = s;
    }
    // Keep default ordering first, then any robot-only ids.
    final ordered = <SoundSlot>[
      for (final d in kDefaultSoundCatalog) byId[d.id]!,
      for (final s in robot)
        if (!kDefaultSoundCatalog.any((d) => d.id == s.id)) s,
    ];
    state = state.copyWith(catalog: ordered, loading: false, fromRobot: true);
    connTrace('sounds', 'catalog from robot: ${robot.length} ids');
  }

  /// Returns null on success, else an error string.
  Future<String?> replace(String soundId, String filePath, String filename) async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(busyId: soundId, progress: 0, clearError: true);
    final err = await _ref.read(soundsApiProvider).replace(
          token: _token,
          deviceId: _deviceId,
          soundId: soundId,
          filePath: filePath,
          filename: filename,
          onProgress: (sent, total) {
            if (total > 0 && mounted) {
              state = state.copyWith(progress: sent / total);
            }
          },
        );
    if (!mounted) return err;
    if (err == null) {
      state = state.copyWith(
        clearBusy: true,
        catalog: [
          for (final s in state.catalog)
            s.id == soundId
                ? s.copyWith(custom: true, updatedAt: DateTime.now())
                : s,
        ],
      );
      connTrace('sounds', 'replaced $soundId with $filename');
    } else {
      state = state.copyWith(clearBusy: true, error: err);
    }
    return err;
  }

  Future<String?> resetOne(String soundId) async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(busyId: soundId, clearError: true);
    final err = await _ref
        .read(soundsApiProvider)
        .reset(token: _token, deviceId: _deviceId, soundId: soundId);
    if (!mounted) return err;
    state = state.copyWith(
      clearBusy: true,
      error: err,
      catalog: err == null
          ? [
              for (final s in state.catalog)
                s.id == soundId ? s.copyWith(custom: false) : s,
            ]
          : null,
    );
    return err;
  }

  /// Factory reset every sound on the robot.
  Future<String?> resetAll() async {
    if (state.busyId != null || state.resettingAll) return 'busy';
    state = state.copyWith(resettingAll: true, clearError: true);
    final err = await _ref
        .read(soundsApiProvider)
        .reset(token: _token, deviceId: _deviceId);
    if (!mounted) return err;
    state = state.copyWith(
      resettingAll: false,
      error: err,
      catalog: err == null
          ? [for (final s in state.catalog) s.copyWith(custom: false)]
          : null,
    );
    connTrace('sounds', 'reset all → ${err ?? 'ok'}');
    return err;
  }
}
