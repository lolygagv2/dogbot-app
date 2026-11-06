import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/ai_connection.dart';
import 'package:wimz_app/data/models/daily_summary.dart';
import 'package:wimz_app/data/models/notification_event.dart';
import 'package:wimz_app/data/models/sound_catalog.dart';

void main() {
  group('DailySummary', () {
    test('parses a full payload including an AI plan', () {
      final s = DailySummary.fromJson({
        'dog_id': 'd1',
        'dog_name': 'Elsa',
        'date': '2026-12-09',
        'headline': 'Quiet morning, two good sits.',
        'stats': {
          'barks': 3,
          'treats': 4,
          'coaching_attempts': 6,
          'coaching_completed': 5,
          'quiet_minutes': 410,
        },
        'highlights': [
          {'time': '09:14', 'text': 'Sat on first cue'},
          'Plain string highlight',
        ],
        'plan': {
          'source': 'claude',
          'items': ['Two sit reps after lunch', 'Calm music at 3pm'],
        },
      });
      expect(s.dogName, 'Elsa');
      expect(s.stats.barks, 3);
      expect(s.stats.coachingSuccessRate, closeTo(5 / 6, 1e-9));
      expect(s.highlights.length, 2);
      expect(s.highlights.first.time, '09:14');
      expect(s.plan, isNotNull);
      expect(s.plan!.items.length, 2);
      expect(AiProvider.fromWire(s.plan!.source), AiProvider.claude);
    });

    test('works with no AI plan and stats only (flat payload tolerated)', () {
      final s = DailySummary.fromJson({'barks': 1, 'treats': 2}, date: '2026-12-09');
      expect(s.plan, isNull);
      expect(s.headline, isNull);
      expect(s.date, '2026-12-09');
      expect(s.stats.treats, 2);
      expect(s.highlights, isEmpty);
    });

    test('empty plan object collapses to null', () {
      final s = DailySummary.fromJson({'plan': {'items': []}});
      expect(s.plan, isNull);
    });
  });

  group('MissionDraft', () {
    test('parses flat and nested draft events', () {
      final flat = MissionDraft.fromEvent({
        'draft_id': 'x1',
        'title': 'Evening sit drill',
        'steps': ['Call', 'Sit', 'Reward'],
        'proposed_by': 'ChatGPT',
      });
      expect(flat!.id, 'x1');
      expect(flat.steps.length, 3);
      expect(flat.provider, AiProvider.chatgpt);

      final nested = MissionDraft.fromEvent({
        'type': 'mission_draft',
        'draft': {'id': 'x2', 'name': 'Quiet time', 'provider': 'anthropic'},
      });
      expect(nested!.id, 'x2');
      expect(nested.title, 'Quiet time');
      expect(nested.provider, AiProvider.claude);
      expect(nested.proposedBy, 'Claude');
    });

    test('rejects a draft without an id', () {
      expect(MissionDraft.fromEvent({'title': 'no id'}), isNull);
    });
  });

  group('attachments', () {
    setUp(() => attachmentBaseUrl = 'https://api.wimzai.com');

    test('finds top-level and nested urls and absolutizes relative paths', () {
      expect(attachmentImageUrl({'image_url': 'https://x/y.jpg'}), 'https://x/y.jpg');
      expect(attachmentImageUrl({'snapshot_url': '/media/a.jpg'}),
          'https://api.wimzai.com/media/a.jpg');
      expect(attachmentClipUrl({'payload': {'clip_url': 'clips/b.mp4'}}),
          'https://api.wimzai.com/clips/b.mp4');
      expect(attachmentClipUrl({'data': {'video_url': ''}}), isNull);
      expect(attachmentImageUrl({}), isNull);
    });

    test('NotificationEvent.fromWsEvent carries attachments', () {
      final n = NotificationEvent.fromWsEvent({
        'type': 'alert',
        'title': 'Bark',
        'image_url': '/m/1.jpg',
        'clip_url': '/m/1.mp4',
      });
      expect(n.imageUrl, endsWith('/m/1.jpg'));
      expect(n.clipUrl, endsWith('/m/1.mp4'));
    });
  });

  group('AiProvider / audit', () {
    test('maps vendor spellings', () {
      expect(AiProvider.fromWire('OpenAI GPT'), AiProvider.chatgpt);
      expect(AiProvider.fromWire('xai'), AiProvider.grok);
      expect(AiProvider.fromWire('perplexity-pro'), AiProvider.perplexity);
      expect(AiProvider.fromWire('unknown'), isNull);
    });

    test('assistant scopes accept list or space-separated string', () {
      expect(AiAssistant.fromJson({'id': '1', 'scopes': ['a', 'b']}).scopes, ['a', 'b']);
      expect(AiAssistant.fromJson({'id': '1', 'scope': 'read:summary write:missions'}).scopes,
          ['read:summary', 'write:missions']);
    });

    test('audit result normalizes', () {
      expect(AiAuditEntry.fromJson({'action': 'get_summary', 'result': 'OK'}).isOk, isTrue);
      expect(AiAuditEntry.fromJson({'action': 'x', 'status': 'denied'}).isOk, isFalse);
    });
  });

  group('SoundSlot', () {
    test('infers groups from wire names and id prefixes', () {
      expect(SoundSlot.groupFromWire('guardian', 'x'), SoundGroup.sgLevel);
      expect(SoundSlot.groupFromWire(null, 'sg_level_3'), SoundGroup.sgLevel);
      expect(SoundSlot.groupFromWire(null, 'music_calm'), SoundGroup.music);
      expect(SoundSlot.groupFromWire(null, 'low_battery'), SoundGroup.alert);
      expect(SoundSlot.groupFromWire(null, 'greeting'), SoundGroup.greeting);
    });

    test('default catalog covers every group with unique ids', () {
      final ids = kDefaultSoundCatalog.map((s) => s.id).toSet();
      expect(ids.length, kDefaultSoundCatalog.length);
      for (final g in SoundGroup.values) {
        expect(kDefaultSoundCatalog.any((s) => s.group == g), isTrue, reason: '$g');
      }
    });
  });
}
