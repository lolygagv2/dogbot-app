import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/domain/providers/coach_provider.dart';

/// Active-trick session tracking: forceTrick sets the highlight, forcing a
/// different trick switches it, a matching coach_reward completes it, and
/// coach teardown clears it.
void main() {
  test('force → switch → matching reward → teardown lifecycle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(coachProvider.notifier);

    // Robot confirms coach mode with a dog identified.
    notifier.debugHandleEvent(WsEvent(
      type: 'coaching_started',
      data: {'dog_id': 'dog-a', 'dog_name': 'Elsa'},
    ));
    var s = container.read(coachProvider);
    expect(s.isActive, isTrue);
    expect(s.activeTrick, isNull);

    // Force a trick → it becomes the active session.
    expect(notifier.forceTrick('sit'), isTrue);
    s = container.read(coachProvider);
    expect(s.activeTrick, 'sit');
    expect(s.isActiveTrick('sit'), isTrue);
    expect(s.isActiveTrick('SIT'), isTrue, reason: 'case-insensitive');

    // Tapping another trick switches the session.
    expect(notifier.forceTrick('spin'), isTrue);
    expect(container.read(coachProvider).activeTrick, 'spin');

    // A reward for a DIFFERENT behavior leaves the forced session in place.
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_reward',
      data: {'behavior': 'sit', 'dog_id': 'dog-a', 'dog_name': 'Elsa'},
    ));
    expect(container.read(coachProvider).activeTrick, 'spin');

    // A reward for the forced trick completes it — highlight clears.
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_reward',
      data: {'behavior': 'spin', 'dog_id': 'dog-a', 'dog_name': 'Elsa'},
    ));
    s = container.read(coachProvider);
    expect(s.activeTrick, isNull);
    expect(s.rewardsGiven, 2);

    // Force again, then leave coach mode → cleared.
    notifier.forceTrick('speak');
    expect(container.read(coachProvider).activeTrick, 'speak');
    notifier.debugHandleEvent(WsEvent(
      type: 'mode_changed',
      data: {'mode': 'idle'},
    ));
    s = container.read(coachProvider);
    expect(s.isActive, isFalse);
    expect(s.activeTrick, isNull);
  });

  test('forceTrick refused when coach inactive — no highlight', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(coachProvider.notifier);

    expect(notifier.forceTrick('sit'), isFalse);
    expect(container.read(coachProvider).activeTrick, isNull);
  });
}
