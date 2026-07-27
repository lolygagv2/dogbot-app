import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'dog_profiles_provider.dart';
import 'mode_provider.dart';

/// Coach session state
class CoachState {
  final bool isActive;
  /// Tricks the robot is currently watching for. Read-only mirror of the
  /// robot's `tricks_available` (sent on `coaching_started`); falls back to
  /// the default list below until the first event arrives. App cannot mutate
  /// this — TRICKS is robot-side configuration with no runtime override API.
  final List<String> watchingFor;
  final int rewardsGiven;
  final String? lastRewardBehavior;
  final DateTime? lastRewardTime;

  /// The trick the coach session is currently running — set on force_trick
  /// (app-initiated) and mirrored from the robot's `coach_progress` ticks
  /// (robot-initiated), so the highlight tracks whatever trick is actually
  /// live. Cleared when a matching reward lands, when a different trick
  /// starts, on coach exit, or by the failsafe timer in [CoachNotifier].
  /// Null = robot is free-watching all tricks.
  final String? activeTrick;
  final String? dogId;
  final String? dogName;
  final String? error;

  const CoachState({
    this.isActive = false,
    this.watchingFor = const ['sit', 'laydown', 'come', 'spin', 'speak'],
    this.rewardsGiven = 0,
    this.lastRewardBehavior,
    this.lastRewardTime,
    this.activeTrick,
    this.dogId,
    this.dogName,
    this.error,
  });

  CoachState copyWith({
    bool? isActive,
    List<String>? watchingFor,
    int? rewardsGiven,
    String? lastRewardBehavior,
    DateTime? lastRewardTime,
    String? activeTrick,
    String? dogId,
    String? dogName,
    String? error,
    bool clearError = false,
    bool clearLastReward = false,
    bool clearActiveTrick = false,
  }) {
    return CoachState(
      isActive: isActive ?? this.isActive,
      watchingFor: watchingFor ?? this.watchingFor,
      rewardsGiven: rewardsGiven ?? this.rewardsGiven,
      lastRewardBehavior: clearLastReward ? null : (lastRewardBehavior ?? this.lastRewardBehavior),
      lastRewardTime: clearLastReward ? null : (lastRewardTime ?? this.lastRewardTime),
      activeTrick: clearActiveTrick ? null : (activeTrick ?? this.activeTrick),
      dogId: dogId ?? this.dogId,
      dogName: dogName ?? this.dogName,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Whether [behavior] is the currently forced trick (case-insensitive).
  bool isActiveTrick(String behavior) =>
      activeTrick != null &&
      activeTrick!.toLowerCase() == behavior.toLowerCase();

  /// Time since last reward in seconds (null if never rewarded)
  int? get secondsSinceLastReward {
    if (lastRewardTime == null) return null;
    return DateTime.now().difference(lastRewardTime!).inSeconds;
  }

  /// Whether reward was recently given (within 3 seconds)
  bool get hasRecentReward {
    final secs = secondsSinceLastReward;
    return secs != null && secs < 3;
  }
}

/// Provider for coach state
final coachProvider = StateNotifierProvider<CoachNotifier, CoachState>((ref) {
  return CoachNotifier(ref);
});

/// Coach state notifier
class CoachNotifier extends StateNotifier<CoachState> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;
  Timer? _rewardClearTimer;
  Timer? _activeTrickTimer;

  /// Failsafe: the robot has no trick-failed/timed-out event, so a forced
  /// trick the dog never performs would stay highlighted forever. Clear the
  /// highlight after this window (robot trick sessions are much shorter).
  static const Duration _activeTrickTimeout = Duration(seconds: 60);

  CoachNotifier(this._ref) : super(const CoachState()) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    final ws = _ref.read(websocketClientProvider);
    _wsSubscription = ws.eventStream.listen(_onWsEvent);
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'coach_reward':
        final behavior = event.data['behavior'] as String?;
        final dogName = event.data['dog_name'] as String?;
        final dogId = event.data['dog_id'] as String?;
        print('Coach: reward event - behavior=$behavior, dog=$dogName ($dogId)');

        // A reward for the forced trick completes that session — drop the
        // active highlight. A reward for some other behavior leaves the
        // forced session (and its highlight) in place.
        final completesForced =
            behavior != null && state.isActiveTrick(behavior);
        if (completesForced) _activeTrickTimer?.cancel();
        state = state.copyWith(
          rewardsGiven: state.rewardsGiven + 1,
          lastRewardBehavior: behavior,
          lastRewardTime: DateTime.now(),
          dogId: dogId,
          dogName: dogName,
          clearActiveTrick: completesForced,
        );

        // Clear last reward after 3 seconds
        _rewardClearTimer?.cancel();
        _rewardClearTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            state = state.copyWith(clearLastReward: true);
          }
        });
        break;

      case 'coaching_started':
        // Build 93: Canonical event name is `coaching_started` (per robot
        // coaching_engine.py:259-261). Robot broadcasts the authoritative
        // TRICKS list as `tricks_available` — app's watchingFor is now a
        // read-only mirror of robot defaults rather than something the app
        // can mutate.
        connTrace('coach-evt', 'coaching_started');
        final dogName = event.data['dog_name'] as String?;
        final dogId = event.data['dog_id'] as String?;
        final tricks = (event.data['tricks_available'] as List?)?.cast<String>();
        _activeTrickTimer?.cancel();
        state = state.copyWith(
          isActive: true,
          dogId: dogId,
          dogName: dogName,
          watchingFor: tricks ?? state.watchingFor,
          rewardsGiven: 0,
          clearError: true,
          clearActiveTrick: true,
        );
        break;

      case 'mode_changed':
        // Build 93: Unified teardown — coach mode exit is observed via
        // mode_changed (away from 'coach') rather than the deprecated
        // coach_stopped event. Robot's mode-change handler is the single
        // source of truth for coach teardown.
        //
        // Build 145: mode_changed INTO coach also activates. Entering coach
        // from the drive screen's mode selector only sends set_mode — nothing
        // called startCoaching(), so isActive stayed false until a
        // coaching_started event arrived. On surfaces where that event never
        // lands (local-AP socket) the trick chips were permanently inert:
        // onTap gated on isActive, so taps produced no highlight, no
        // snackbar, nothing.
        final newMode = event.data['mode']?.toString();
        if (newMode == 'coach' && !state.isActive) {
          connTrace('coach-evt', 'mode_changed:coach — activating');
          _activeTrickTimer?.cancel();
          state = state.copyWith(
            isActive: true,
            rewardsGiven: 0,
            clearError: true,
            clearActiveTrick: true,
          );
        } else if (newMode != null && newMode != 'coach' && state.isActive) {
          connTrace('coach-evt', 'mode_changed:$newMode — deactivating');
          _activeTrickTimer?.cancel();
          state = state.copyWith(isActive: false, clearActiveTrick: true);
        }
        break;

      case 'coach_progress':
        // Build 145: the robot's coaching engine emits progress ticks
        // (greeting / command / watching phases). When a tick names a trick,
        // mirror it as the active trick so the highlight tracks whatever the
        // engine is ACTUALLY running — robot-initiated sessions included —
        // instead of only app-forced taps. Trick key read defensively until
        // the robot instance confirms the payload contract.
        // Robot contract confirmed 2026-07-26: key is `trick`, stage key is
        // `stage` (greeting|command|watching — watching ticks at ~2Hz).
        final progressTrick = (event.data['trick'] ??
                event.data['behavior'] ??
                event.data['current_trick'])
            ?.toString();
        final stage = (event.data['stage'] ?? event.data['phase'])?.toString();
        connTrace('coach-evt', 'coach_progress stage=$stage trick=$progressTrick');
        if (progressTrick != null && progressTrick.isNotEmpty) {
          // A progress tick proves the engine is live — activate if a
          // coaching_started / mode_changed was missed (belt and braces for
          // the local-AP event gaps). Watching-stage ticks repeat at ~2Hz:
          // re-arm the failsafe every tick, but only emit a new state when
          // something actually changed so listeners don't rebuild at 2Hz.
          _armActiveTrickFailsafe(progressTrick);
          if (!state.isActive || state.activeTrick != progressTrick) {
            state = state.copyWith(isActive: true, activeTrick: progressTrick);
          }
        }
        final progressDogName = event.data['dog_name']?.toString();
        final progressDogId = event.data['dog_id']?.toString();
        if (progressDogName != null || progressDogId != null) {
          state = state.copyWith(dogName: progressDogName, dogId: progressDogId);
        }
        break;

      case 'trick_forced':
        // Robot's force_trick confirmation (fbc5d10: only emitted on real
        // success, never after a rejected trick). `replaced` reports whether
        // a running session was actually cancelled by our replace:true.
        // State already moved optimistically in forceTrick(); this is the
        // diagnostics breadcrumb that proves the command landed.
        connTrace('coach-evt',
            'trick_forced trick=${event.data['trick']} '
            'replaced=${event.data['replaced']}');
        break;

      case 'detection':
        // Detection events while coaching - update dog identity if present
        if (state.isActive) {
          final dogName = event.data['dog_name'] as String?;
          final dogId = event.data['dog_id'] as String?;
          if (dogName != null || dogId != null) {
            state = state.copyWith(dogName: dogName, dogId: dogId);
          }
        }
        break;
    }
  }

  /// Start coach mode.
  ///
  /// Build 93: Mode change is the entire start signal. The previous
  /// `start_coach` WS frame's `behaviors` / `dog_id` / `dog_name` payload was
  /// silently discarded by the robot — behaviors are robot-side configuration
  /// (DEFAULT_TRICKS in coaching_engine.py) and dog identity comes from ArUco
  /// vision. To pin a specific dog or trick for the session, send
  /// `force_dog` / `force_trick` separately after the `mode_changed: coach`
  /// event lands. The `behaviors` arg here is purely a local UI hint —
  /// populates the watching-for chip wall, doesn't change robot behavior.
  Future<void> startCoaching({List<String>? behaviors}) async {
    await _ref.read(modeStateProvider.notifier).setMode(RobotMode.coach);

    state = state.copyWith(
      isActive: true,
      watchingFor: behaviors ?? state.watchingFor,
      rewardsGiven: 0,
      clearError: true,
      clearLastReward: true,
    );
  }

  /// Stop coach mode.
  ///
  /// Build 93: Unified teardown via set_mode(idle) — the same code path the
  /// home-screen EXIT button uses. The dedicated stop_coach WS command was a
  /// no-op on the cloud-relay path the app actually uses, leaving coach mode
  /// stuck running on the robot. Routing through set_mode hits the robot's
  /// mode-change handler (the single source of truth for coach teardown via
  /// engine.stop()) and avoids the FSM-override race that stop_coach didn't
  /// participate in. Local isActive flips optimistically; the mode_changed
  /// event arriving back from the robot also flips it as a safety net.
  void stopCoaching() {
    _ref.read(modeStateProvider.notifier).setMode(RobotMode.idle, source: 'coach_exit');
    _rewardClearTimer?.cancel();
    _activeTrickTimer?.cancel();
    state = state.copyWith(isActive: false, clearActiveTrick: true);
  }

  // Build 93: setBehaviors() removed. The `coach_set_behaviors` WS command
  // had no robot-side handler — TRICKS is loaded once at engine construction
  // (coaching_engine.py, DEFAULT_TRICKS fallback) with no runtime mutation
  // API. Robot broadcasts the authoritative list via the `tricks_available`
  // field on `coaching_started`; the app treats watchingFor as read-only.

  /// Force a specific trick (Build 38; Build 106: now carries dog identity).
  ///
  /// Resolves dog identity in priority order:
  ///   1. ArUco detection (coachState.dogId/dogName) — what the camera sees.
  ///   2. Selected profile (selectedDogProvider) — user's intent when nothing
  ///      is detected yet.
  ///   3. None → return false. Caller should surface a snackbar telling the
  ///      user to select a dog or wait for detection. Sending a nameless
  ///      force_trick would have the robot fall back to a generic "Dog" TTS,
  ///      which was the original complaint.
  bool forceTrick(String trick) {
    if (!state.isActive) {
      connTrace('coach-force-trick', 'refused — coach not active');
      return false;
    }

    String? dogId = state.dogId;
    String? dogName = state.dogName;
    if (dogId == null && dogName == null) {
      final selected = _ref.read(selectedDogProvider);
      dogId = selected?.id;
      dogName = selected?.name;
    }

    if (dogId == null && dogName == null) {
      connTrace('coach-force-trick', 'refused — no dog identified/selected');
      return false;
    }

    // Switch path (robot contract fbc5d10): a tap while a session is already
    // running sends replace:true so the robot hard-cancels the current trick
    // and starts this one immediately — without the flag the tap would only
    // stage the trick for the NEXT session and the highlight would lie.
    // activeTrick is the app's proxy for "session running" (covers both
    // app-forced taps and robot-initiated sessions mirrored via
    // coach_progress).
    final replace = state.activeTrick != null;
    final ws = _ref.read(websocketClientProvider);
    ws.sendForceTrick(trick, dogId: dogId, dogName: dogName, replace: replace);
    connTrace('coach-force-trick', '$trick dog=$dogName ($dogId) replace=$replace');

    _armActiveTrickFailsafe(trick);
    state = state.copyWith(activeTrick: trick);
    return true;
  }

  /// (Re)arm the failsafe that clears [CoachState.activeTrick] if no reward
  /// or newer trick arrives within [_activeTrickTimeout].
  void _armActiveTrickFailsafe(String trick) {
    _activeTrickTimer?.cancel();
    _activeTrickTimer = Timer(_activeTrickTimeout, () {
      if (mounted && state.activeTrick == trick) {
        state = state.copyWith(clearActiveTrick: true);
      }
    });
  }

  /// Clear state
  void clearState() {
    _rewardClearTimer?.cancel();
    _activeTrickTimer?.cancel();
    state = const CoachState();
  }

  @visibleForTesting
  void debugHandleEvent(WsEvent event) => _onWsEvent(event);

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _rewardClearTimer?.cancel();
    _activeTrickTimer?.cancel();
    super.dispose();
  }
}
