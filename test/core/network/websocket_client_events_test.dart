import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/core/network/websocket_client.dart';

/// Regression tests for the inbound-frame gates in WebSocketClient._onMessage:
/// the store-and-forward seq watermark and the target-device filter.
///
/// Build 140 bug: audio_state (verified NOT in the relay's FEED_WORTHY_EVENTS
/// replay buffer, but stamped with a seq on live forward) went through the
/// watermark gate. A watermark sitting ahead of a robot's live counter
/// silently swallowed every audio_state from it — now-playing text rendered
/// for one robot (wimz_robot_05) and never for others.
void main() {
  final client = WebSocketClient.instance;

  /// Relay-style live audio_state frame, exactly as forward_event_to_owner
  /// delivers it (flat JSON, `event` key, top-level device_id).
  String audioStateFrame({
    required String device,
    int? seq,
    String track = 'default/Trancewimz.mp3',
  }) =>
      jsonEncode({
        'event': 'audio_state',
        'device_id': device,
        'state': 'playing',
        'track': track,
        'playing': true,
        'playlist_index': 6,
        'playlist_length': 14,
        'id': 'aabbccddeeff00112233445566778899',
        'timestamp': '2026-07-12T18:00:00Z',
        if (seq != null) 'seq': seq,
      });

  String feedFrame({required String device, required int seq, bool buffered = false}) =>
      jsonEncode({
        'type': 'treat',
        'device_id': device,
        'seq': seq,
        if (buffered) 'buffered': true,
        'success': true,
      });

  late List<WsEvent> received;
  late StreamSubscription<WsEvent> sub;

  setUp(() {
    client.debugResetForTest();
    received = [];
    // eventStream is a plain (async) broadcast stream — deliveries need an
    // event-loop turn before assertions, hence the pumps below.
    sub = client.eventStream.listen(received.add);
  });

  tearDown(() async {
    await sub.cancel();
    client.debugResetForTest();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('audio_state passes even when its seq is below the watermark', () async {
    // Watermark far ahead of the robot's live counter — the exact state that
    // ate every audio_state from wimz_robot_01 pre-fix.
    client.setTargetDevice('wimz_robot_01');
    client.debugSetWatermark(99999, deviceId: 'wimz_robot_01');

    client.debugHandleMessage(audioStateFrame(device: 'wimz_robot_01', seq: 5));
    await pump();

    expect(received, hasLength(1));
    expect(received.single.type, 'audio_state');
    expect(received.single.data['track'], 'default/Trancewimz.mp3');
    expect(received.single.data['playing'], true);
  });

  test('audio_state without a seq passes the watermark gate', () async {
    client.setTargetDevice('wimz_robot_01');
    client.debugSetWatermark(99999, deviceId: 'wimz_robot_01');

    client.debugHandleMessage(audioStateFrame(device: 'wimz_robot_01'));
    await pump();

    expect(received.map((e) => e.type), contains('audio_state'));
  });

  test('audio_state never advances the watermark (Build 127 lesson)', () async {
    client.setTargetDevice('wimz_robot_01');
    client.debugSetWatermark(100, deviceId: 'wimz_robot_01');

    client.debugHandleMessage(
        audioStateFrame(device: 'wimz_robot_01', seq: 200000));
    await pump();

    expect(client.debugWatermark, 100,
        reason: 'a transient event advancing the watermark would drop '
            'buffered feed events on the next reconnect');

    // A feed event just above the true watermark must still be delivered.
    client.debugHandleMessage(feedFrame(device: 'wimz_robot_01', seq: 101));
    await pump();
    expect(received.map((e) => e.type), contains('treat'));
  });

  test('feed events at or below the watermark still dedup', () async {
    client.setTargetDevice('wimz_robot_01');
    client.debugSetWatermark(100, deviceId: 'wimz_robot_01');

    client.debugHandleMessage(
        feedFrame(device: 'wimz_robot_01', seq: 50, buffered: true));
    await pump();

    expect(received, isEmpty);
    expect(client.debugWatermark, 100);
  });

  test('feed events above the watermark advance it', () async {
    client.setTargetDevice('wimz_robot_01');
    client.debugSetWatermark(100, deviceId: 'wimz_robot_01');

    client.debugHandleMessage(feedFrame(device: 'wimz_robot_01', seq: 150));
    await pump();

    expect(received.map((e) => e.type), contains('treat'));
    expect(client.debugWatermark, 150);
  });

  test('audio_state from a non-target robot is filtered', () async {
    // Multi-robot owner: the relay forwards ALL owned robots' events; another
    // robot's now-playing must not clobber the connected robot's UI.
    client.setTargetDevice('wimz_robot_05');

    client.debugHandleMessage(audioStateFrame(device: 'wimz_robot_01', seq: 5));
    await pump();

    expect(received, isEmpty);
  });

  test('audio_state with no device_id (local mode) is accepted', () async {
    client.setTargetDevice('local_robot');

    client.debugHandleMessage(jsonEncode({
      'event': 'audio_state',
      'state': 'playing',
      'track': 'default/Wimz_theme.mp3',
      'playing': true,
    }));
    await pump();

    expect(received.map((e) => e.type), contains('audio_state'));
  });

  test('WsEvent.fromJson parses a flat relay audio_state frame', () {
    final event = WsEvent.fromJson(
        jsonDecode(audioStateFrame(device: 'wimz_robot_01', seq: 7))
            as Map<String, dynamic>);

    expect(event.type, 'audio_state');
    expect(event.data['track'], 'default/Trancewimz.mp3');
    expect(event.data['playing'], true);
    expect(event.data['playlist_index'], 6);
    expect(event.seq, 7);
  });
}
