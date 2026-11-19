import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/data/models/dog_profile.dart';
import 'package:wimz_app/domain/providers/dog_profiles_provider.dart';
import 'package:wimz_app/domain/providers/robot_state_provider.dart';
import 'package:wimz_app/domain/providers/settings_provider.dart';

/// Which dog the picker presents as SELECTED.
///
/// "No dog selected" applies in exactly one case: cloud mode, after a
/// `robot_state` was received with `selected_dog_id` null. The absence of
/// a record is never "no dog", and local / AP mode (no relay) always uses
/// the app's own selection, sent with the existing select_dog frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = WebSocketClient.instance;

  const elsa = DogProfile(id: '019f58ad-03c9-7aff-adae-b697fb058ffc', name: 'Elsa');
  const bezik = DogProfile(id: '01a183fe-0169-7d8b-ac62-5d58727473bf', name: 'Bezik');

  late ProviderContainer container;

  /// Two dogs on disk with Bezik as the app's own selection.
  Future<void> start({required bool local}) async {
    final dogs = jsonEncode([elsa.toJson(), bezik.toJson()]);
    final scope = local ? 'local' : 'anonymous';
    SharedPreferences.setMockInitialValues({
      'dog_profiles_$scope': dogs,
      'selected_dog_$scope': bezik.id,
      if (local) 'local_mode_enabled': true,
    });
    client.debugResetForTest();
    client.setTargetDevice(local ? 'local_robot' : 'wimz_robot_05');
    container = ProviderContainer();
    container.read(settingsProvider);
    await settle();
    expect(container.read(isLocalRobotLinkProvider), local);
    // Instantiate the listeners (profiles, selection, state record).
    container.read(robotStateProvider);
    container.read(shownSelectedDogProvider);
    await settle();
    expect(container.read(dogProfilesProvider), hasLength(2));
    expect(container.read(selectedDogProvider)?.id, bezik.id);
  }

  tearDown(() async {
    await settle();
    container.dispose();
    client.debugResetForTest();
  });

  void robotState({required String device, String? selectedDog, int version = 1}) {
    client.debugHandleMessage(jsonEncode({
      'type': 'robot_state',
      'device_id': device,
      'robot_online': true,
      'mode': 'idle',
      'asleep': false,
      'selected_dog_id': selectedDog,
      'selected_dog_applied': selectedDog != null,
      'session_dog_id': null,
      'state_version': version,
      'updated_at': '2026-11-19T18:47:32.551Z',
      'source': 'app',
      'reason': null,
    }));
  }

  test('cloud, no robot_state received: the app\'s own selection is shown',
      () async {
    await start(local: false);
    expect(container.read(robotStateProvider), isNull);
    expect(container.read(shownSelectedDogProvider)?.id, bezik.id);
  });

  test('cloud, robot_state with selected_dog_id null: "No dog selected"',
      () async {
    await start(local: false);
    robotState(device: 'wimz_robot_05', selectedDog: null);
    await settle();
    expect(container.read(robotStateProvider), isNotNull);
    expect(container.read(shownSelectedDogProvider), isNull);
    // The per-dog screens keep the last dog's data.
    expect(container.read(selectedDogProvider)?.id, bezik.id);
  });

  test('cloud, robot_state with a selected_dog_id: that dog is shown',
      () async {
    await start(local: false);
    robotState(device: 'wimz_robot_05', selectedDog: elsa.id);
    await settle();
    expect(container.read(shownSelectedDogProvider)?.id, elsa.id);
    expect(container.read(selectedDogProvider)?.id, elsa.id);
  });

  test('local / AP: the app\'s own selection, existing select_dog frame',
      () async {
    await start(local: true);
    final sent = <Map<String, dynamic>>[];
    client.debugCommandSink = sent.add;

    expect(container.read(shownSelectedDogProvider)?.id, bezik.id);

    // A record with no selected dog changes nothing in local mode.
    robotState(device: 'local_robot', selectedDog: null);
    await settle();
    expect(container.read(shownSelectedDogProvider)?.id, bezik.id);
    // ...nor does one naming another dog.
    robotState(device: 'local_robot', selectedDog: elsa.id, version: 2);
    await settle();
    expect(container.read(selectedDogProvider)?.id, bezik.id);
    expect(container.read(shownSelectedDogProvider)?.id, bezik.id);

    // Picking a dog: selected at once, sent with the pre-v2 frame.
    await container.read(selectedDogProvider.notifier).selectDog(elsa);
    await settle();
    expect(container.read(selectedDogProvider)?.id, elsa.id);
    expect(container.read(shownSelectedDogProvider)?.id, elsa.id);
    expect(container.read(dogSelectionStatusProvider).isPending, isFalse);
    final frames = sent.where((f) => f['command'] == 'select_dog').toList();
    expect(frames, hasLength(1));
    final f = frames.single;
    expect(f['type'], 'command');
    expect(f['device_id'], 'local_robot');
    expect(f.containsKey('command_id'), isFalse);
    expect(f['data'], {'dog_id': elsa.id, 'dog_name': 'Elsa'});
  });
}

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));
