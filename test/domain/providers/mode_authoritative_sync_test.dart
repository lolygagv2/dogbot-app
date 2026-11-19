import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/domain/providers/connection_provider.dart';
import 'package:wimz_app/domain/providers/mode_provider.dart';
import 'package:wimz_app/domain/providers/settings_provider.dart';

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

  tearDown(() async {
    // robotStateProvider reads auth; let its async start-up settle before
    // the container goes away.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.dispose();
    client.debugResetForTest();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  /// Local-AP (no relay): the pre-v2 mode sources still apply there.
  Future<void> useLocalMode() async {
    SharedPreferences.setMockInitialValues({'local_mode_enabled': true});
    container.read(settingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(settingsProvider).localModeEnabled, isTrue);
  }

  test('connected.current_mode syncs the UI mode', () async {
    await useLocalMode();
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
    await useLocalMode();
    client.debugCommandSink = (_) {};
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.manual, reason: 'test');
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
    await useLocalMode();
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

  // ───────────── ROBOT-STATE v2 ─────────────

  Map<String, dynamic> robotState({
    String device = 'local_robot',
    String mode = 'idle',
    bool asleep = false,
    bool online = true,
    String? sessionDog,
    String? selectedDog,
    int version = 1,
    String source = 'robot',
  }) =>
      {
        'type': 'robot_state',
        'device_id': device,
        'robot_online': online,
        'mode': mode,
        'asleep': asleep,
        'selected_dog_id': selectedDog,
        'selected_dog_applied': selectedDog != null,
        'session_dog_id': sessionDog,
        'state_version': version,
        'updated_at': '2026-11-19T18:47:32.551Z',
        'source': source,
        'reason': null,
      };

  test('C1 set_mode frame: command_id, device_id, reason — never source',
      () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.silentGuardian, reason: 'dropdown');

    expect(sent, hasLength(1));
    final f = sent.single;
    expect(f['type'], 'command');
    expect(f['command'], 'set_mode');
    expect(f['device_id'], 'local_robot');
    expect(f['command_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    final data = f['data'] as Map<String, dynamic>;
    expect(data['mode'], 'silent_guardian');
    expect(data.containsKey('dog_id'), isTrue);
    expect(data['dog_id'], isNull);
    expect(data['reason'], 'dropdown');
    expect(data.containsKey('source'), isFalse);
    expect(data['timestamp'], isA<String>());
    expect(container.read(modeStateProvider).pendingMode,
        RobotMode.silentGuardian);
  });

  test('robot_offline result: error shown, mode unchanged, nothing pending',
      () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.silentGuardian, reason: 'dropdown');
    client.debugHandleMessage(jsonEncode({
      'type': 'command_result',
      'command_id': sent.single['command_id'],
      'command': 'set_mode',
      'success': false,
      'result': {},
      'error': 'robot_offline',
      'duration_ms': 3,
    }));
    await pump();

    final s = container.read(modeStateProvider);
    expect(s.currentMode, RobotMode.idle);
    expect(s.isChanging, isFalse);
    expect(s.pendingMode, isNull);
    expect(s.error, isNotNull);
    expect(sent, hasLength(1), reason: 'nothing is retried');
  });

  test('reason "expired" in a command_result shows "Robot was busy"',
      () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.coach, reason: 'dropdown');
    client.debugHandleMessage(jsonEncode({
      'type': 'command_result',
      'command_id': sent.single['command_id'],
      'command': 'set_mode',
      'success': false,
      'reason': 'expired',
      'result': {},
      'error': null,
    }));
    await pump();
    final s = container.read(modeStateProvider);
    expect(s.isChanging, isFalse);
    expect(s.currentMode, RobotMode.idle);
    expect(s.error, 'Robot was busy. Try again.');
  });

  test('successful set_mode result settles the pending mode', () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    await container
        .read(modeStateProvider.notifier)
        .setMode(RobotMode.coach, reason: 'dropdown');
    client.debugHandleMessage(jsonEncode({
      'type': 'command_result',
      'command_id': sent.single['command_id'],
      'command': 'set_mode',
      'success': true,
      'result': {'mode': 'coach', 'session_dog_id': null},
      'error': null,
      'duration_ms': 40,
    }));
    await pump();
    // The result only ends pending: the mode shown is the record's.
    var s = container.read(modeStateProvider);
    expect(s.isChanging, isFalse);
    expect(s.currentMode, RobotMode.idle);
    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'coach', version: 4)));
    await pump();
    s = container.read(modeStateProvider);
    expect(s.currentMode, RobotMode.coach);
  });

  test('pending ends when state_version increases', () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    final notifier = container.read(modeStateProvider.notifier);
    client.debugHandleMessage(jsonEncode(robotState(version: 3)));
    await pump();
    await notifier.setMode(RobotMode.silentGuardian, reason: 'dropdown');
    // The same version again (e.g. the on-connect copy) is not an answer.
    client.debugHandleMessage(jsonEncode(robotState(version: 3)));
    await pump();
    expect(container.read(modeStateProvider).isChanging, isTrue);
    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'silent_guardian', version: 4)));
    await pump();
    final s = container.read(modeStateProvider);
    expect(s.isChanging, isFalse);
    expect(s.currentMode, RobotMode.silentGuardian);
  });

  test('local-AP: silence after the wait is taken as done (unchanged)',
      () async {
    await useLocalMode();
    client.debugCommandSink = (_) {};
    final notifier = container.read(modeStateProvider.notifier);
    await notifier.setMode(RobotMode.coach, reason: 'dropdown');
    notifier.debugFireTimeout();
    expect(container.read(modeStateProvider).currentMode, RobotMode.coach);
  });

  test('after the wait: revert + error, a later record still renders',
      () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    final notifier = container.read(modeStateProvider.notifier);
    // A relay record exists, so silence is not taken as success.
    client.debugHandleMessage(jsonEncode(robotState(version: 1)));
    await pump();
    await notifier.setMode(RobotMode.silentGuardian, reason: 'dropdown');
    notifier.debugFireTimeout();
    var s = container.read(modeStateProvider);
    expect(s.isChanging, isFalse, reason: 'never frozen on "switching"');
    expect(s.currentMode, RobotMode.idle);
    expect(s.error, isNotNull);
    expect(sent, hasLength(1), reason: 'nothing re-sent');

    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'silent_guardian', version: 2)));
    await pump();
    s = container.read(modeStateProvider);
    expect(s.currentMode, RobotMode.silentGuardian);
  });

  test('robot_state from elsewhere drives the selector (T5/T6)', () async {
    container.read(modeStateProvider);
    client.debugHandleMessage(jsonEncode(robotState(
        mode: 'silent_guardian',
        sessionDog: '019f58ad-03c9-7aff-adae-b697fb058ffc',
        version: 7,
        source: 'connector')));
    await pump();
    expect(container.read(modeStateProvider).currentMode,
        RobotMode.silentGuardian);

    // A status echo no longer decides the mode once a record exists.
    client.debugHandleMessage(
        jsonEncode({'type': 'status_update', 'mode': 'coach'}));
    await pump();
    expect(container.read(modeStateProvider).currentMode,
        RobotMode.silentGuardian);

    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'idle', version: 8, source: 'connector')));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.idle);

    // An older record is not applied over a newer one.
    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'coach', version: 5)));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.idle);
  });

  test("another robot's robot_state is ignored", () async {
    container.read(modeStateProvider);
    client.debugHandleMessage(jsonEncode(
        robotState(device: 'other_robot', mode: 'coach', version: 3)));
    await pump();
    expect(container.read(modeStateProvider).currentMode, RobotMode.idle);
  });

  test('sleep is not a mode: C3 set_sleep + robot_state.asleep', () async {
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;
    final notifier = container.read(modeStateProvider.notifier);

    // "sleep" as a mode string is not a mode and is ignored.
    client.debugHandleMessage(
        jsonEncode({'type': 'status_update', 'mode': 'sleep'}));
    await pump();
    expect(container.read(robotAsleepProvider), isFalse);
    expect(RobotMode.tryFromString('sleep'), isNull);

    await notifier.setSleep(true, reason: 'sleep_button');
    final f = sent.single;
    expect(f['command'], 'set_sleep');
    expect(f['command_id'], isNotNull);
    expect(f['data'], {'asleep': true, 'reason': 'sleep_button'});
    expect(container.read(modeStateProvider).pendingAsleep, isTrue);
    expect(container.read(robotAsleepProvider), isFalse,
        reason: 'not assumed before the robot confirms');

    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'idle', asleep: true, version: 2)));
    await pump();
    var s = container.read(modeStateProvider);
    expect(s.asleep, isTrue);
    expect(s.pendingAsleep, isNull);
    expect(s.currentMode, RobotMode.idle);

    // Wake: set_sleep false, confirmed by its command_result.
    await notifier.setSleep(false, reason: 'wake_button');
    expect(sent.last['data'], {'asleep': false, 'reason': 'wake_button'});
    client.debugHandleMessage(jsonEncode({
      'type': 'command_result',
      'command_id': sent.last['command_id'],
      'command': 'set_sleep',
      'success': true,
      'result': {'asleep': false, 'mode': 'idle'},
      'error': null,
      'duration_ms': 12,
    }));
    await pump();
    s = container.read(modeStateProvider);
    expect(s.pendingAsleep, isNull);
    expect(s.asleep, isTrue, reason: 'asleep is rendered from the record');
    client.debugHandleMessage(
        jsonEncode(robotState(mode: 'idle', asleep: false, version: 3)));
    await pump();
    s = container.read(modeStateProvider);
    expect(s.asleep, isFalse);
    expect(s.currentMode, RobotMode.idle);
    expect(sent.every((f) => f['command'] != 'set_mode'), isTrue);
  });

  test('local-AP: a robot_asleep error is taken as the robot being asleep',
      () async {
    await useLocalMode();
    container.read(modeStateProvider);
    client.debugHandleMessage(jsonEncode({
      'type': 'error',
      'code': 'robot_asleep',
      'message': 'video is off while asleep',
    }));
    await pump();
    expect(container.read(robotAsleepProvider), isTrue);
  });
}
