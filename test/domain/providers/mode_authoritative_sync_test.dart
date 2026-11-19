import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/domain/providers/connection_provider.dart';
import 'package:wimz_app/domain/providers/mode_provider.dart';

/// Build 146: robot-authoritative mode sync (the set_mode-stomping fix).
/// On (re)connect the robot reports its mode via `connected.current_mode` /
/// `initial_status.data.system_state`; the app adopts it — overriding any
/// stale sovereign user selection — and sends nothing. Buffered (replayed)
/// mission events must not flip live mode state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = WebSocketClient.instance;

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client.debugResetForTest();
    client.setTargetDevice('local_robot');
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    client.debugResetForTest();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('connected.current_mode syncs the UI mode', () async {
    container.read(modeStateProvider); // instantiate listener

    client.debugHandleMessage(jsonEncode({
      'type': 'connected',
      'current_mode': 'coach',
    }));
    await pump();

    expect(container.read(modeStateProvider).currentMode, RobotMode.coach);
  });

  test('initial_status.system_state syncs and overrides sovereign selection',
      () async {
    // Sovereign selection requires a "connected" app — demo mode provides it.
    container.read(connectionProvider.notifier).enableDemoMode();
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.manual, source: 'test');
    expect(container.read(modeStateProvider).pendingMode, RobotMode.manual);

    // Robot says coach on connect — pre-146 the sovereign guard silently
    // discarded this, leaving the app convinced of its own stale mode (and
    // navigation handlers then re-asserted it at the robot).
    client.debugHandleMessage(jsonEncode({
      'type': 'initial_status',
      'data': {'system_state': 'coach'},
    }));
    await pump();

    final s = container.read(modeStateProvider);
    expect(s.currentMode, RobotMode.coach);
    expect(s.isChanging, isFalse);
    expect(s.pendingMode, isNull);
  });

  test('buffered mission events do not flip live mode state', () async {
    container.read(modeStateProvider);

    // Live mission start → mission mode, locked.
    client.debugHandleMessage(jsonEncode({
      'type': 'mission_progress',
      'action': 'started',
      'mission_id': 'm1',
      'mission_name': 'Morning Sit',
    }));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.mission);

    // A REPLAYED completion from the store-and-forward buffer is history —
    // it must not end the live mission (pre-146 it even SENT set_mode:idle).
    client.debugHandleMessage(jsonEncode({
      'type': 'mission_complete',
      'buffered': true,
      'mission_id': 'm0',
    }));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.mission);

    // The live completion does end it.
    client.debugHandleMessage(jsonEncode({
      'type': 'mission_complete',
      'mission_id': 'm1',
    }));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.idle);
  });

  test('robot-reported sleep shows Asleep even over a user selection; '
      'an explicit mode_changed wakes it', () async {
    container.read(connectionProvider.notifier).enableDemoMode();
    final notifier = container.read(modeStateProvider.notifier);
    await notifier.setMode(RobotMode.silentGuardian, source: 'test');
    client.debugHandleMessage(
        jsonEncode({'type': 'mode_changed', 'mode': 'silent_guardian'}));
    await pump();
    expect(container.read(modeStateProvider).currentMode,
        RobotMode.silentGuardian);

    // Robot falls asleep by itself: a status echo is enough.
    client.debugHandleMessage(
        jsonEncode({'type': 'status_update', 'mode': 'sleep'}));
    await pump();
    expect(container.read(robotAsleepProvider), isTrue);

    // ...and reports waking.
    client.debugHandleMessage(
        jsonEncode({'type': 'mode_changed', 'mode': 'idle'}));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.idle);
    expect(container.read(robotAsleepProvider), isFalse);
  });

  test('Sleep control: stale idle echoes do not wake a requested sleep',
      () async {
    container.read(connectionProvider.notifier).enableDemoMode();
    final notifier = container.read(modeStateProvider.notifier);
    await notifier.setMode(RobotMode.sleep, source: 'sleep_button');
    expect(container.read(modeStateProvider).pendingMode, RobotMode.sleep);
    client.debugHandleMessage(
        jsonEncode({'type': 'mode_changed', 'mode': 'sleep'}));
    await pump();
    expect(container.read(robotAsleepProvider), isTrue);

    client.debugHandleMessage(
        jsonEncode({'type': 'status_update', 'mode': 'idle'}));
    await pump();
    expect(container.read(robotAsleepProvider), isTrue);

    // Wake button → idle, confirmed by the robot.
    await notifier.setMode(RobotMode.idle, source: 'wake_button');
    client.debugHandleMessage(
        jsonEncode({'type': 'mode_changed', 'mode': 'idle'}));
    await pump();
    expect(container.read(robotAsleepProvider), isFalse);
  });
}
