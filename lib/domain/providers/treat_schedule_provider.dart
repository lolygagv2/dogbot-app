import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/conn_trace.dart';
import '../../data/datasources/dog_settings_api.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';
import 'settings_provider.dart';

/// Relay `treat_schedule` setting value (brief 2026-11-09 §3/§6):
/// `{daily_cap_enabled, daily_cap, max_per_hour, ...}`.
///
/// `daily_cap_enabled:false` (or a null cap) = unlimited. `max_per_hour`
/// 0 = no hourly limit (the app has no control for it). Unknown keys are
/// preserved in [raw] so a future PUT can send the "full value" back.
class TreatSchedule {
  final bool dailyCapEnabled;

  /// Daily cap as stored — kept even when disabled so re-enabling restores
  /// it. Null when the relay never stored one.
  final int? dailyCap;
  final int maxPerHour;
  final Map<String, dynamic> raw;

  const TreatSchedule({
    this.dailyCapEnabled = false,
    this.dailyCap,
    this.maxPerHour = 0,
    this.raw = const {},
  });

  /// Effective daily cap: null = unlimited.
  int? get effectiveCap => dailyCapEnabled ? dailyCap : null;
  bool get isUnlimited => effectiveCap == null;

  static TreatSchedule fromJson(Map<String, dynamic> j) {
    final cap = _int(j['daily_cap']);
    final enabledRaw = j['daily_cap_enabled'];
    // Older rows may lack the flag: a positive cap means enabled.
    final enabled = enabledRaw is bool ? enabledRaw : (cap != null && cap > 0);
    return TreatSchedule(
      dailyCapEnabled: enabled,
      dailyCap: cap,
      maxPerHour: _int(j['max_per_hour']) ?? 0,
      raw: Map<String, dynamic>.from(j),
    );
  }

  /// Full value for PUT (§6): known fields over the preserved raw map.
  Map<String, dynamic> toJson() => {
        ...raw,
        'daily_cap_enabled': dailyCapEnabled,
        if (dailyCap != null) 'daily_cap': dailyCap,
        'max_per_hour': maxPerHour,
      };

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class TreatScheduleState {
  final TreatSchedule value;
  final int? version;
  final String? updatedBy;
  final bool loaded;
  final bool loading;
  final String? error;

  /// Relay has no settings slice / key (404).
  final bool unsupported;
  final String? dogId;

  const TreatScheduleState({
    this.value = const TreatSchedule(),
    this.version,
    this.updatedBy,
    this.loaded = false,
    this.loading = false,
    this.error,
    this.unsupported = false,
    this.dogId,
  });

  /// True when the last writer was an assistant (Claude connector / voice
  /// agent) or the robot rather than this app — surfaced in Settings so the
  /// owner knows why the limit isn't what they set.
  bool get changedElsewhere {
    final by = updatedBy?.toLowerCase();
    if (by == null || by.isEmpty) return false;
    return !(by.startsWith('app') || by.startsWith('user') || by.startsWith('owner'));
  }

  TreatScheduleState copyWith({
    TreatSchedule? value,
    int? version,
    String? updatedBy,
    bool? loaded,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? unsupported,
    String? dogId,
  }) =>
      TreatScheduleState(
        value: value ?? this.value,
        version: version ?? this.version,
        updatedBy: updatedBy ?? this.updatedBy,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        unsupported: unsupported ?? this.unsupported,
        dogId: dogId ?? this.dogId,
      );
}

/// Relay-shared daily treat limit — GET
/// `/api/dogs/{dog}/settings/treat_schedule` (brief 2026-11-09 §3). The
/// relay keeps every owned dog's row identical (follow-up 2026-11-09), so
/// the selected dog's row is read only because the route needs a dog id.
///
/// Writes still go over the WebSocket `mission_config` message (§1: the
/// relay reads it and fans the value out to every owned dog), so this
/// provider is read-only: it loads the real value and copies it into
/// [settingsProvider] (which the Settings tile renders), and re-reads a
/// moment after the app sends so the UI shows what the relay saved.
/// Cloud only; silent in local-AP mode.
final treatScheduleProvider =
    StateNotifierProvider<TreatScheduleNotifier, TreatScheduleState>(
        (ref) => TreatScheduleNotifier(ref));

class TreatScheduleNotifier extends StateNotifier<TreatScheduleState> {
  static const key = 'treat_schedule';

  /// Delay between our own `mission_config` send and the confirming GET —
  /// long enough for relay persistence, short enough to feel live.
  static const resyncDelay = Duration(milliseconds: 1500);

  final Ref _ref;
  Timer? _resync;
  int _loadSeq = 0;

  TreatScheduleNotifier(this._ref) : super(const TreatScheduleState()) {
    _ref.listen<String?>(selectedDogProvider.select((d) => d?.id), (prev, next) {
      if (next != null && next != prev) load();
    });
    _ref.read(settingsProvider.notifier).onDailyLimitSent = scheduleResync;
    _ref.onDispose(() {
      _resync?.cancel();
      _ref.read(settingsProvider.notifier).onDailyLimitSent = null;
    });
  }

  String? get _token => _ref.read(settingsProvider).localModeEnabled
      ? null
      : _ref.read(authProvider).token;
  String? get _dogId => _ref.read(selectedDogProvider)?.id;

  /// Re-read the shared value after our own send (or after a
  /// "Treat limit raised" push) so Settings reflects the relay, not the
  /// phone's stale copy.
  void scheduleResync({Duration? after}) {
    _resync?.cancel();
    _resync = Timer(after ?? resyncDelay, () => load());
  }

  Future<void> load() async {
    final token = _token, dogId = _dogId;
    if (token == null || dogId == null) {
      state = TreatScheduleState(dogId: dogId);
      return;
    }
    final seq = ++_loadSeq;
    state = state.copyWith(loading: true, clearError: true, dogId: dogId);
    final r = await _ref.read(dogSettingsApiProvider).get(token, dogId, key);
    if (!mounted || seq != _loadSeq) return;
    if (r.row != null) {
      final v = TreatSchedule.fromJson(r.row!.value);
      state = TreatScheduleState(
        dogId: dogId,
        value: v,
        version: r.row!.version,
        updatedBy: r.row!.updatedBy,
        loaded: true,
      );
      connTrace('treat-limit',
          'relay dog=$dogId enabled=${v.dailyCapEnabled} cap=${v.dailyCap} hourly=${v.maxPerHour} v${r.row!.version} by=${r.row!.updatedBy}');
      // The tile renders settingsProvider; make it show the relay's truth.
      await _ref.read(settingsProvider.notifier).applyRemoteDailyLimit(
            enabled: v.dailyCapEnabled,
            cap: v.dailyCap,
          );
    } else if (r.unsupported) {
      state = TreatScheduleState(dogId: dogId, unsupported: true);
      connTrace('treat-limit', 'relay has no treat_schedule for $dogId (404)');
    } else {
      state = state.copyWith(loading: false, error: r.error);
    }
  }
}
