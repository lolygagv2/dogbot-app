import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import 'mode_provider.dart';

/// Coach session state
class CoachState {
  final bool isActive;
  final List<String> watchingFor;  // Behaviors being watched
  final int rewardsGiven;
  final String? lastRewardBehavior;
  final DateTime? lastRewardTime;
  final String? dogName;
  final String? error;

  const CoachState({
    this.isActive = false,
    this.watchingFor = const ['sit', 'down', 'stand'],
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

      case 'coach_started':
        print('Coach: started event');
        final dogName = event.data['dog_name'] as String?;
        final behaviors = (event.data['behaviors'] as List?)?.cast<String>();
        state = state.copyWith(
          isActive: true,
          dogName: dogName,
          watchingFor: behaviors ?? state.watchingFor,
          rewardsGiven: 0,
          clearError: true,
        );
        break;

      case 'coach_stopped':
        print('Coach: stopped event');
        state = state.copyWith(isActive: false);
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

  /// Start coach mode
  Future<void> startCoaching({List<String>? behaviors}) async {
    final ws = _ref.read(websocketClientProvider);

    // First set mode to coach
    await _ref.read(modeStateProvider.notifier).setMode(RobotMode.coach);

    // Then send start_coach command
    ws.sendCommand('start_coach', {
      if (behaviors != null) 'behaviors': behaviors,
    });

    state = state.copyWith(
      isActive: true,
      watchingFor: behaviors ?? state.watchingFor,
      rewardsGiven: 0,
      clearError: true,
      clearLastReward: true,
    );
  }

  /// Stop coach mode
  void stopCoaching() {
    final ws = _ref.read(websocketClientProvider);
    ws.sendCommand('stop_coach', {});

    _rewardClearTimer?.cancel();
    state = state.copyWith(isActive: false);

    // Set mode back to idle
    _ref.read(modeStateProvider.notifier).setMode(RobotMode.idle);
  }

  /// Update behaviors to watch for
  void setBehaviors(List<String> behaviors) {
    state = state.copyWith(watchingFor: behaviors);
    if (state.isActive) {
      // Update robot if coaching is active
      final ws = _ref.read(websocketClientProvider);
      ws.sendCommand('coach_set_behaviors', {'behaviors': behaviors});
    }
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
