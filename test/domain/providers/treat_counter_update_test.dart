import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/data/models/telemetry.dart';
import 'package:wimz_app/domain/providers/telemetry_provider.dart';

/// B160 regression (2026-09-04): the home-screen treat chip stopped updating.
/// Since B153 the chip rendered `treats_given`, which the robot only sends in
/// treat_counter_ack / treats_* events; the periodic status/battery frames
/// carry `treats_remaining`. After a reset ack the chip latched on
/// "0/44 given" while every later dispense updated a field it no longer
/// showed. The chip now renders remaining, which follows whichever field the
/// latest frame carries.
void main() {
  late ProviderContainer container;
  late TelemetryNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(telemetryProvider.notifier);
  });

  int? remaining() => container.read(treatsRemainingProvider);

  test('reset ack (given only) then remaining-only status frames keep updating',
      () {
    // Robot ack after "Refilled — Reset Counter": given=0, capacity 44.
    notifier.debugHandleEvent(WsEvent(
      type: 'treat_counter_ack',
      data: {'treats_given': 0, 'treat_capacity': 44, 'treats_remaining': 44},
    ));
    expect(remaining(), 44);

    // Periodic status frames carry ONLY treats_remaining — this is the path
    // that used to be invisible on the chip.
    notifier.debugHandleEvent(WsEvent(
      type: 'status_update',
      data: {'battery': 80, 'mode': 'idle', 'treats_remaining': 43},
    ));
    expect(remaining(), 43);

    notifier.debugHandleEvent(WsEvent(
      type: 'battery',
      data: {'level': 79, 'charging': false, 'treats_remaining': 41},
    ));
    expect(remaining(), 41);

    notifier.debugHandleEvent(WsEvent(
      type: 'reward',
      data: {'subtype': 'treat_dispensed', 'treats_remaining': 40},
    ));
    expect(remaining(), 40);
    expect(container.read(telemetryProvider).lastTreatTime, isNotNull);
  });

  test('given-only frame derives remaining against the hard 44', () {
    notifier.debugHandleEvent(WsEvent(
      type: 'treats_low',
      data: {'treats_given': 40},
    ));
    expect(remaining(), 4);
  });

  test('remaining wins when both fields are present', () {
    notifier.debugHandleEvent(WsEvent(
      type: 'status_update',
      data: {'treats_given': 3, 'treats_remaining': 17},
    ));
    expect(remaining(), 17,
        reason: 'after a partial load the robot-derived remaining is the '
            'truth; 44 - given would be wrong');
  });

  test('deprecated treats_loaded alias still feeds remaining', () {
    notifier.debugHandleEvent(WsEvent(
      type: 'treat_status',
      data: {'treats_loaded': 12},
    ));
    expect(remaining(), 12);
  });

  test('clamps to [0, 44] and reports null until any field arrives', () {
    expect(remaining(), isNull);
    notifier.debugHandleEvent(WsEvent(
      type: 'status_update',
      data: {'treats_remaining': -3},
    ));
    expect(remaining(), 0);
    notifier.debugHandleEvent(WsEvent(
      type: 'status_update',
      data: {'treats_remaining': 50},
    ));
    expect(remaining(), kTreatCapacity);
  });

  test('a badly typed counter field does not drop the whole frame', () {
    notifier.debugHandleEvent(WsEvent(
      type: 'status_update',
      data: {'battery': 66, 'treats_remaining': '39'},
    ));
    expect(remaining(), 39);
    expect(container.read(telemetryProvider).battery, 66);
  });
}
