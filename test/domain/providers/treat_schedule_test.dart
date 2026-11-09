import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/core/services/push_routes.dart';
import 'package:wimz_app/data/models/treat_refusal.dart';
import 'package:wimz_app/domain/providers/treat_schedule_provider.dart';

/// Relay brief 2026-11-09 "Treat limit is now synced through the relay":
/// the shared `treat_schedule` value (§3/§6), the push route (§5) and the
/// robot's treat refusals (§7).
void main() {
  group('TreatSchedule', () {
    test('parses the relay value; disabled = unlimited but cap is kept', () {
      final t = TreatSchedule.fromJson(
          {'daily_cap_enabled': false, 'daily_cap': 35, 'max_per_hour': 0});
      expect(t.dailyCapEnabled, isFalse);
      expect(t.dailyCap, 35);
      expect(t.effectiveCap, isNull);
      expect(t.isUnlimited, isTrue);
      expect(t.maxPerHour, 0);
    });

    test('enabled cap is the effective cap', () {
      final t = TreatSchedule.fromJson({'daily_cap_enabled': true, 'daily_cap': 65});
      expect(t.effectiveCap, 65);
      expect(t.isUnlimited, isFalse);
    });

    test('missing flag: positive cap means enabled; numeric strings ok', () {
      expect(TreatSchedule.fromJson({'daily_cap': '20'}).effectiveCap, 20);
      expect(TreatSchedule.fromJson({'daily_cap': 0}).dailyCapEnabled, isFalse);
      expect(TreatSchedule.fromJson({}).isUnlimited, isTrue);
    });

    test('toJson preserves unknown keys (full value for PUT)', () {
      final t = TreatSchedule.fromJson({
        'daily_cap_enabled': true,
        'daily_cap': 10,
        'max_per_hour': 3,
        'window': {'start': '08:00', 'end': '20:00'},
      });
      final j = t.toJson();
      expect(j['window'], {'start': '08:00', 'end': '20:00'});
      expect(j['daily_cap_enabled'], isTrue);
      expect(j['daily_cap'], 10);
      expect(j['max_per_hour'], 3);
    });
  });

  group('TreatScheduleState.changedElsewhere', () {
    test('assistant / robot writers flag, app writers do not', () {
      expect(const TreatScheduleState(updatedBy: 'agent').changedElsewhere, isTrue);
      expect(const TreatScheduleState(updatedBy: 'connector:cl_1').changedElsewhere, isTrue);
      expect(const TreatScheduleState(updatedBy: 'robot').changedElsewhere, isTrue);
      expect(const TreatScheduleState(updatedBy: 'app').changedElsewhere, isFalse);
      expect(const TreatScheduleState(updatedBy: 'user:42').changedElsewhere, isFalse);
      expect(const TreatScheduleState().changedElsewhere, isFalse);
    });
  });

  group('pushRouteFor', () {
    test('treat_limit_raised opens Settings → Daily treat limit', () {
      expect(
        pushRouteFor({
          'type': 'alert',
          'dog_id': 'd1',
          'kind': 'treat_limit_raised',
          'actor': 'agent',
        }),
        kSettingsTreatLimitRoute,
      );
      expect(kSettingsTreatLimitRoute, '/settings?focus=treat_limit');
    });

    test('other relay pushes open the activity feed; non-push data → null', () {
      expect(pushRouteFor({'type': 'bark'}), '/activity');
      expect(pushRouteFor(null), isNull);
      expect(pushRouteFor({}), isNull);
    });
  });

  group('TreatRefusal.tryParse', () {
    test('error frame with code (proposed shape)', () {
      final r = TreatRefusal.tryParse(WsEvent.fromJson({
        'type': 'error',
        'code': 'treat_cap_reached',
        'command': 'dispense_treat',
        'used': 65,
        'cap': 65,
        'resets_at': '2026-11-10T00:00:00Z',
      }));
      expect(r, isNotNull);
      expect(r!.code, TreatRefusal.capReached);
      expect(r.used, 65);
      expect(r.cap, 65);
      expect(r.resetsAt, isNotNull);
    });

    test('UPPER_CASE robot code and type-as-code frames', () {
      expect(
        TreatRefusal.tryParse(WsEvent.fromJson({'type': 'error', 'code': 'TREAT_RATE'}))?.code,
        TreatRefusal.rate,
      );
      expect(
        TreatRefusal.tryParse(WsEvent.fromJson({'type': 'treat_window_closed'}))?.code,
        TreatRefusal.windowClosed,
      );
    });

    test('command_result success:false for dispense_treat', () {
      final r = TreatRefusal.tryParse(WsEvent.fromJson({
        'type': 'command_result',
        'command': 'dispense_treat',
        'success': false,
        'result': {'code': 'treat_cap_reached', 'used': 20, 'cap': 20},
      }));
      expect(r?.code, TreatRefusal.capReached);
      expect(r?.used, 20);
      expect(r?.cap, 20);
    });

    test('ignores unrelated errors and successful results', () {
      expect(TreatRefusal.tryParse(WsEvent.fromJson({'type': 'error', 'code': 'RATE_LIMITED'})), isNull);
      expect(
        TreatRefusal.tryParse(WsEvent.fromJson(
            {'type': 'command_result', 'command': 'dispense_treat', 'success': true})),
        isNull,
      );
      expect(
        TreatRefusal.tryParse(WsEvent.fromJson(
            {'type': 'command_result', 'command': 'take_photo', 'success': false, 'code': 'treat_rate'})),
        isNull,
      );
    });
  });
}
