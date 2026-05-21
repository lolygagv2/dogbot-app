import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'control_provider.dart';
import 'telemetry_provider.dart';

/// Volume slider state.
///
/// [level] is the value the slider shows (0-100); `null` until the robot's
/// volume is first known from telemetry. [syncing] is true from a user change
/// until the robot's telemetry confirms it (or a timeout gives up).
class VolumeState {
  final int? level;
  final bool syncing;

  const VolumeState({this.level, this.syncing = false});

  VolumeState copyWith({int? level, bool? syncing}) => VolumeState(
        level: level ?? this.level,
        syncing: syncing ?? this.syncing,
      );
}

final volumeProvider = StateNotifierProvider<VolumeNotifier, VolumeState>(
  (ref) => VolumeNotifier(ref),
);

/// Owns the volume slider value.
///
/// The robot's `VolumeManager` is the single source of truth — it persists
/// across reboots and can change outside the app (e.g. the Xbox Share
/// button). Its volume arrives in `status` telemetry every ~5s. This notifier
/// reconciles the slider to that telemetry value, except during the brief
/// window after a user change while waiting for the robot to confirm. There
/// is no hard-coded "last known volume" — the value is only ever the robot's.
class VolumeNotifier extends StateNotifier<VolumeState> {
  final Ref _ref;
  Timer? _syncTimeout;

  /// Safety net: if telemetry never confirms a user change, stop showing
  /// "syncing" and trust telemetry again. Longer than the 5s telemetry cycle.
  static const _syncTimeoutDuration = Duration(seconds: 8);

  VolumeNotifier(this._ref) : super(const VolumeState()) {
    // Reconcile the slider whenever the robot reports its volume.
    _ref.listen<int?>(
      telemetryProvider.select((t) => t.volume),
      (_, next) => _reconcile(next),
      fireImmediately: true,
    );
  }

  /// The robot reported its volume. Adopt it — unless we're mid-sync and it
  /// hasn't caught up to the user's change yet.
  void _reconcile(int? robotVolume) {
    if (robotVolume == null) return; // volume unavailable this cycle
    if (state.syncing) {
      if (robotVolume == state.level) {
        // Robot confirmed the user's change.
        _syncTimeout?.cancel();
        state = state.copyWith(syncing: false);
      }
      // else: robot hasn't applied it yet — keep the optimistic value.
      return;
    }
    // Not syncing — telemetry is the truth (covers external changes like
    // the Xbox Share button cycling volume).
    if (robotVolume != state.level) {
      state = state.copyWith(level: robotVolume);
    }
  }

  /// Optimistic update while the user drags the slider — no command sent.
  void preview(int level) {
    state = state.copyWith(level: level.clamp(0, 100));
  }

  /// The user released the slider — send to the robot and await telemetry
  /// confirmation. Idempotent; safe to call on every release.
  void commit(int level) {
    final clamped = level.clamp(0, 100);
    state = VolumeState(level: clamped, syncing: true);
    _ref.read(audioControlProvider).setVolume(clamped);
    _syncTimeout?.cancel();
    _syncTimeout = Timer(_syncTimeoutDuration, () {
      // Gave up waiting for confirmation — trust telemetry from here on.
      if (mounted) state = state.copyWith(syncing: false);
    });
  }

  @override
  void dispose() {
    _syncTimeout?.cancel();
    super.dispose();
  }
}
