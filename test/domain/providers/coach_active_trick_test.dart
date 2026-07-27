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

  test('mode_changed into coach activates without coaching_started', () {
    // Build 145: entering coach via the drive-screen mode selector never
    // called startCoaching(), and on the local-AP socket coaching_started
    // may never arrive — isActive stayed false and every trick tap was
    // inert. mode_changed:coach must activate on its own.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(coachProvider.notifier);

    notifier.debugHandleEvent(WsEvent(
      type: 'mode_changed',
      data: {'mode': 'coach'},
    ));
    final s = container.read(coachProvider);
    expect(s.isActive, isTrue);

    // With a dog identified, taps now work end-to-end.
    notifier.debugHandleEvent(WsEvent(
      type: 'detection',
      data: {'dog_id': 'dog-a', 'dog_name': 'Elsa'},
    ));
    expect(notifier.forceTrick('sit'), isTrue);
    expect(container.read(coachProvider).activeTrick, 'sit');

    // Re-hearing mode_changed:coach while already active must NOT wipe the
    // running session (mode events can repeat).
    notifier.debugHandleEvent(WsEvent(
      type: 'mode_changed',
      data: {'mode': 'coach'},
    ));
    expect(container.read(coachProvider).activeTrick, 'sit');
  });

  test('coach_progress mirrors the robot-initiated trick as active', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(coachProvider.notifier);

    // A progress tick alone proves the engine is live: activates AND
    // highlights the trick the robot chose (no app tap involved).
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_progress',
      data: {'phase': 'command', 'trick': 'laydown', 'dog_name': 'Elsa'},
    ));
    final s = container.read(coachProvider);
    expect(s.isActive, isTrue);
    expect(s.activeTrick, 'laydown');
    expect(s.dogName, 'Elsa');

    // Robot moves on to a different trick → highlight follows.
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_progress',
      data: {'phase': 'command', 'behavior': 'spin'},
    ));
    expect(container.read(coachProvider).activeTrick, 'spin',
        reason: 'behavior key accepted until robot confirms payload contract');

    // A trickless tick (e.g. greeting phase) leaves the session untouched.
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_progress',
      data: {'phase': 'greeting'},
    ));
    expect(container.read(coachProvider).activeTrick, 'spin');

    // Matching reward completes the robot-initiated session too.
    notifier.debugHandleEvent(WsEvent(
      type: 'coach_reward',
      data: {'behavior': 'spin'},
    ));
    expect(container.read(coachProvider).activeTrick, isNull);
  });
}
