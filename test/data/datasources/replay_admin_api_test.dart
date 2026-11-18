import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/core/constants/api_endpoints.dart';
import 'package:wimz_app/data/datasources/replay_admin_api.dart';
import 'package:wimz_app/domain/providers/demo_replay_provider.dart';

/// Records every request and answers from [reply].
class _Recorder implements HttpClientAdapter {
  final calls = <({String method, Uri uri, Object? body})>[];
  ResponseBody Function(RequestOptions o) reply =
      (_) => _json(200, {'status': 'loaded'});

  static ResponseBody _json(int status, Object body) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    calls.add((method: o.method, uri: o.uri, body: o.data));
    return reply(o);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Recorder rec;
  late ReplayAdminApi api;
  const bezik = ReplayTarget(dogId: 'dog-bezik', deviceId: 'wimz_robot_02');
  const elsa = ReplayTarget(dogId: 'dog-elsa', deviceId: 'wimz_robot_02');

  setUp(() {
    rec = _Recorder();
    final dio = Dio(BaseOptions(baseUrl: 'https://relay.test'))
      ..httpClientAdapter = rec;
    api = ReplayAdminApi(dio);
  });

  test('one tap of each button: URL + body carry the selected dog and robot',
      () async {
    await api.reset('t', bezik);
    await api.load('t', kReplaySeedGoodDay, bezik);
    await api.load('t', kReplaySeedBadDay, bezik);
    await api.jumpTo('t', '15:30', bezik);
    await api.jumpTo('t', '17:00', bezik);
    await api.start('t', bezik, speed: 120);
    await api.pause('t', bezik);

    final report = [
      for (final c in rec.calls) '${c.method} ${c.uri} ${jsonEncode(c.body)}'
    ];
    // ignore: avoid_print
    report.forEach(print);
    const t = '"dog_id":"dog-bezik","device_id":"wimz_robot_02"';
    expect(report, [
      'POST https://relay.test/admin/replay/reset {$t}',
      'POST https://relay.test/admin/replay/load {"seed":"demo_good_day.json",$t}',
      'POST https://relay.test/admin/replay/load {"seed":"demo_bad_day.json",$t}',
      'POST https://relay.test/admin/replay/jump {"to":"15:30",$t}',
      'POST https://relay.test/admin/replay/jump {"to":"17:00",$t}',
      'POST https://relay.test/admin/replay/start {"speed":120.0,$t}',
      'POST https://relay.test/admin/replay/pause {$t}',
    ]);
  });

  test('a different selected dog changes the target; no robot omits device_id',
      () async {
    await api.load('t', kReplaySeedGoodDay, elsa);
    expect((rec.calls.single.body as Map)['dog_id'], 'dog-elsa');

    await api.reset('t', const ReplayTarget(dogId: 'dog-elsa'));
    expect(rec.calls.last.body, {'dog_id': 'dog-elsa'});

    await api.getState('t', target: elsa);
    expect(rec.calls.last.uri.queryParameters,
        {'dog_id': 'dog-elsa', 'device_id': 'wimz_robot_02'});
  });

  test('a failed button call reports status code + relay error text', () async {
    rec.reply = (_) => _Recorder._json(409, {
          'detail': {'code': 'replay_not_loaded'}
        });
    await expectLater(
      api.jumpTo('t', '15:30', bezik),
      throwsA(isA<ReplayCallError>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.display, 'display',
              'POST /admin/replay/jump → HTTP 409 · replay_not_loaded')),
    );
  });

  test('404 on a button is an error on the panel, not "not admin"', () async {
    rec.reply = (_) => _Recorder._json(404, {
          'detail': {'code': 'seed_not_found', 'seed': 'x.json'}
        });
    await expectLater(api.load('t', 'x.json', bezik),
        throwsA(isA<ReplayCallError>().having((e) => e.status, 'status', 404)));
    // Only the state probe treats 403/404 as "hide the panel".
    await expectLater(api.getState('t'), throwsA(isA<ReplayNotAdmin>()));
  });

  test('409 replay_other_dog carries the dog that holds the replay', () async {
    rec.reply = (_) => _Recorder._json(409, {
          'detail': {
            'code': 'replay_other_dog',
            'loaded_dog_id': 'dog-elsa',
            'status': 'running',
            'seed': 'demo_bad_day.json'
          }
        });
    await expectLater(
        api.jumpTo('t', '15:30', bezik),
        throwsA(isA<ReplayCallError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.loadedDogId, 'loadedDogId', 'dog-elsa')));
  });

  test('load / jump / busy_with response fields (relay reply 2026-11-18)', () {
    final good = ReplayState.fromJson({
      'status': 'loaded',
      'seed': 'demo_good_day.json',
      'dog_id': 'dog-bezik',
      'date': '2026-11-18',
      'landed': 31,
      'landed_date': '2026-11-17',
      'emitted': 0,
    });
    expect(good.landed, 31);
    expect(good.landedDate, '2026-11-17');
    expect(good.date, '2026-11-18');

    final bad = ReplayState.fromJson(
        {'status': 'loaded', 'landed': 0, 'landed_date': null, 'emitted': 5});
    expect(bad.landed, 0);
    expect(bad.landedDate, isNull);

    final busy = ReplayState.fromJson({
      'status': 'idle',
      'dog_id': 'dog-bezik',
      'virtual_time': null,
      'busy_with': {'dog_id': 'dog-elsa', 'status': 'running', 'seed': 'x'},
    });
    final s = const DemoReplayState().copyWith(replay: busy);
    expect(s.replayIsFor('dog-bezik'), isFalse);
    expect(s.otherReplayDog('dog-bezik'), 'dog-elsa');
    expect(s.virtualWallTimeFor('dog-bezik'), isNull);
  });

  test('non-JSON error body is shown as text', () async {
    rec.reply = (_) => ResponseBody.fromString('Bad Gateway', 502);
    await expectLater(
      api.getDogStatus('t', 'dog-bezik'),
      throwsA(isA<ReplayCallError>().having((e) => e.display, 'display',
          'GET ${ApiEndpoints.dogStatus('dog-bezik')} → HTTP 502 · Bad Gateway')),
    );
  });

  test('panel clock / loaded state only apply to the selected dog', () {
    final s = const DemoReplayState().copyWith(
      replay: ReplayState.fromJson({
        'status': 'paused',
        'dog_id': 'demo_dog',
        'virtual_time': '2026-11-17T07:00:00-05:00',
      }),
    );
    expect(s.replayIsFor('dog-bezik'), isFalse);
    expect(s.virtualWallTimeFor('dog-bezik'), isNull);
    expect(s.virtualWallTimeFor('demo_dog'), DateTime(2026, 11, 17, 7));
  });
}
