import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
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
  final String? dogName;
  final String? error;

  const CoachState({
    this.isActive = false,
    this.watchingFor = const ['sit', 'laydown', 'come', 'spin', 'speak'],
    this.rewardsGiven = 0,
    this.lastRewardBehavior,
    this.lastRewardTime,
    this.dogName,
    this.error,
  });

  CoachState copyWith({
    bool? isActive,
    List<String>? watchingFor,
    int? rewardsGiven,
    String? lastRewardBehavior,
    DateTime? lastRewardTime,
    String? dogName,
    String? error,
    bool clearError = false,
    bool clearLastReward = false,
  }) {
    return CoachState(
      isActive: isActive ?? this.isActive,
      watchingFor: watchingFor ?? this.watchingFor,
      rewardsGiven: rewardsGiven ?? this.rewardsGiven,
      lastRewardBehavior: clearLastReward ? null : (lastRewardBehavior ?? this.lastRewardBehavior),
      lastRewardTime: clearLastReward ? null : (lastRewardTime ?? this.lastRewardTime),
      dogName: dogName ?? this.dogName,
      error: clearError ? null : (error ?? this.error),
    );
  }

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
        print('Coach: reward event - behavior=$behavior, dog=$dogName');

        state = state.copyWith(
          rewardsGiven: state.rewardsGiven + 1,
          lastRewardBehavior: behavior,
          lastRewardTime: DateTime.now(),
          dogName: dogName,
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
        print('Coach: coaching_started event');
        final dogName = event.data['dog_name'] as String?;
        final tricks = (event.data['tricks_available'] as List?)?.cast<String>();
        state = state.copyWith(
          isActive: true,
          dogName: dogName,
          watchingFor: tricks ?? state.watchingFor,
          rewardsGiven: 0,
          clearError: true,
        );
        break;

      case 'mode_changed':
        // Build 93: Unified teardown — coach mode exit is observed via
        // mode_changed (away from 'coach') rather than the deprecated
        // coach_stopped event. Robot's mode-change handler is the single
        // source of truth for coach teardown.
        final newMode = event.data['mode'] as String?;
        if (newMode != null && newMode != 'coach' && state.isActive) {
          print('Coach: mode changed to $newMode — deactivating');
          state = state.copyWith(isActive: false);
        }
        break;

      case 'detection':
        // Detection events while coaching - update dog name if present
        if (state.isActive) {
          final dogName = event.data['dog_name'] as String?;
          if (dogName != null) {
            state = state.copyWith(dogName: dogName);
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
    state = state.copyWith(isActive: false);
  }

  // Build 93: setBehaviors() removed. The `coach_set_behaviors` WS command
  // had no robot-side handler — TRICKS is loaded once at engine construction
  // (coaching_engine.py, DEFAULT_TRICKS fallback) with no runtime mutation
  // API. Robot broadcasts the authoritative list via the `tricks_available`
  // field on `coaching_started`; the app treats watchingFor as read-only.

  /// Force a specific trick (Build 38)
  /// Sends force_trick command to robot - robot will start session for this trick
  void forceTrick(String trick) {
    if (!state.isActive) return;

    final ws = _ref.read(websocketClientProvider);
    ws.sendForceTrick(trick);
    print('Coach: Forcing trick: $trick');
  }

  /// Clear state
  void clearState() {
    _rewardClearTimer?.cancel();
    state = const CoachState();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _rewardClearTimer?.cancel();
    super.dispose();
  }
}
