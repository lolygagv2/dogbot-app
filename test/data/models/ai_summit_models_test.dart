import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/ai_connection.dart';
import 'package:wimz_app/data/models/daily_summary.dart';
import 'package:wimz_app/data/models/notification_event.dart';
import 'package:wimz_app/data/models/sound_catalog.dart';

/// Wire shapes per .claude/APP_BRIEF_FROM_RELAY_2026-11-06.md (verified
/// against the relay routers on 2026-11-06); the B165 draft shapes stay
/// accepted for a robot serving the paths locally.
void main() {
  group('DailySummary (relay roll-up)', () {
    test('parses counts / totals / time_to_settle / top_episodes', () {
      final s = DailySummary.fromJson({
        'dog_id': 'd1',
        'date': '2026-12-09',
        'tz': 'America/New_York',
        'counts': {
          'bark_episode': 3,
          'intervention': 4,
          'settle': 2,
          'pacing': 1,
          'departure': 1,
          'arrival': 1,
          'treat': 5,
          'music': 2,
          'mission_run': 2,
        },
        'totals': {
          'bark_s': 240,
          'pacing_s': 95,
          'music_s': 1800,
          'treats': 5,
          'treat_cap': 10,
          'alone_s': 14400,
          'interventions_by_kind': {'sound': 3, 'treat': 1},
          'missions_success': 1,
          'missions_fail': 1,
        },
        'time_to_settle': {'n': 2, 'unresolved': 1, 'median_s': 75, 'mean_s': 80},
        'top_episodes': [
          {
            'event_id': 'e1',
            'ts': '2026-12-09T14:03:11-05:00',
            'duration_s': 94,
            'bark_count': 18,
            'severity': 'high',
            'settle_s': 120,
            'interventions': ['sound', 'treat'],
            'image_url': '/api/media/download/x.jpg',
          },
        ],
        'event_count': 21,
      });
      expect(s.stats.barks, 3);
      expect(s.stats.treats, 5);
      expect(s.stats.treatCap, 10);
      expect(s.stats.guardianInterventions, 4);
      expect(s.stats.settleMedianS, 75);
      expect(s.stats.aloneSeconds, 14400);
      expect(s.stats.interventionsByKind['sound'], 3);
      expect(s.stats.missionRuns, 2);
      expect(s.stats.coachingSuccessRate, closeTo(0.5, 1e-9));
      expect(s.episodes.single.barkCount, 18);
      expect(s.episodes.single.severity, 'high');
      expect(s.episodes.single.ts, isNotNull);
      expect(s.episodes.single.imageUrl, '/api/media/download/x.jpg');
      expect(s.eventCount, 21);
      expect(s.isEmpty, isFalse);
      expect(s.plan, isNull);
      expect(s.headline, isNull);
    });

    test('empty day (event_count 0, zero counts) reports isEmpty', () {
      final s = DailySummary.fromJson({
        'dog_id': 'd1',
        'date': '2026-12-09',
        'counts': {'bark_episode': 0, 'treat': 0},
        'totals': {'treats': 0, 'treat_cap': 10},
        'time_to_settle': {'n': 0},
        'top_episodes': [],
        'event_count': 0,
      });
      expect(s.isEmpty, isTrue);
      expect(s.stats.treatCap, 10);
    });

    test('still parses the B165 draft shape with an AI plan', () {
      final s = DailySummary.fromJson({
        'dog_name': 'Elsa',
        'headline': 'Quiet morning.',
        'stats': {'barks': 3, 'treats': 4, 'coaching_attempts': 6, 'coaching_completed': 5},
        'highlights': [
          {'time': '09:14', 'text': 'Sat on first cue'},
          'Plain string highlight',
        ],
        'plan': {'source': 'claude', 'items': ['Two sit reps after lunch']},
      }, date: '2026-12-09');
      expect(s.dogName, 'Elsa');
      expect(s.date, '2026-12-09');
      expect(s.stats.barks, 3);
      expect(s.stats.coachingSuccessRate, closeTo(5 / 6, 1e-9));
      expect(s.highlights.length, 2);
      expect(s.plan!.items.single, 'Two sit reps after lunch');
      expect(AiProvider.fromWire(s.plan!.source), AiProvider.claude);
      expect(s.isEmpty, isFalse);
    });

    test('empty plan object collapses to null', () {
      expect(DailySummary.fromJson({'plan': {'items': []}}).plan, isNull);
    });
  });

  group('MissionDraft', () {
    final relayFrame = {
      'type': 'mission_draft',
      'dog_id': 'dog_1',
      'draft_id': 'd_abc123',
      'draft': {
        'id': 'm_recall',
        'type': 'recall',
        'name': 'Evening recall',
        'enabled': true,
        'trigger': {'kind': 'departure', 'delay_s': 300, 'cooldown_s': 7200},
        'duration_s': 120,
        'reward_treats': 1,
        'goal': 'Come when called while alone',
      },
      'warnings': ['Overlaps quiet hours'],
      'actor': 'connector:cl_9f8e',
      'created_at': '2026-11-06T10:00:00Z',
    };

    test('parses the relay WS frame (draft_id on the envelope, draft.id = mission id)', () {
      final d = MissionDraft.fromEvent(relayFrame)!;
      expect(d.id, 'd_abc123');
      expect(d.missionId, 'm_recall');
      expect(d.title, 'Evening recall');
      expect(d.missionType, 'recall');
      expect(d.triggerKind, 'departure');
      expect(d.delayS, 300);
      expect(d.durationS, 120);
      expect(d.rewardTreats, 1);
      expect(d.goal, 'Come when called while alone');
      expect(d.summary, 'Come when called while alone');
      expect(d.warnings, ['Overlaps quiet hours']);
      expect(d.actorKind, DraftActorKind.connector);
      expect(d.actorClientId, 'cl_9f8e');
      expect(d.proposedBy, isNull); // resolved via the connector list
      expect(d.dogId, 'dog_1');
      expect(d.createdAt, isNotNull);
      expect(d.status, isNull);
    });

    test('voice agent actor and list-row status', () {
      final d = MissionDraft.fromEvent({
        ...relayFrame,
        'actor': 'agent',
        'status': 'approved',
        'mission_id': 'm_recall',
      })!;
      expect(d.actorKind, DraftActorKind.agent);
      expect(d.isFromVoiceAgent, isTrue);
      expect(d.status, 'approved');
    });

    test('still parses the B165 flat shape', () {
      final flat = MissionDraft.fromEvent({
        'draft_id': 'x1',
        'title': 'Evening sit drill',
        'summary': 'Three short sits',
        'steps': ['Call', 'Sit 3s', 'Reward'],
        'proposed_by': 'Claude',
        'provider': 'claude',
      })!;
      expect(flat.id, 'x1');
      expect(flat.title, 'Evening sit drill');
      expect(flat.steps.length, 3);
      expect(flat.proposedBy, 'Claude');
      expect(flat.provider, AiProvider.claude);
      expect(flat.actorKind, DraftActorKind.unknown);
    });

    test('rejects a frame without a draft id', () {
      expect(MissionDraft.fromEvent({'draft': {'name': 'x'}}), isNull);
    });
  });

  group('AiAssistant / AiAuditEntry (relay rows)', () {
    test('connector row uses client_id / client_name / scopes', () {
      final a = AiAssistant.fromJson({
        'client_id': 'cl_9f8e',
        'client_name': 'Claude',
        'scopes': ['read', 'settings', 'photos'],
        'connected_at': '2026-11-06T10:00:00Z',
        'last_used_at': null,
        'active_tokens': 2,
      });
      expect(a.id, 'cl_9f8e');
      expect(a.name, 'Claude');
      expect(a.provider, AiProvider.claude);
      expect(a.scopes, ['read', 'settings', 'photos']);
      expect(a.activeTokens, 2);
      expect(a.lastUsedAt, isNull);
    });

    test('audit row maps tool/outcome/result_summary', () {
      final e = AiAuditEntry.fromJson({
        'id': 42,
        'ts': '2026-11-06T10:05:00Z',
        'actor': 'connector:cl_9f8e',
        'client_name': 'ChatGPT',
        'tool': 'take_photo',
        'dog_id': 'dog_1',
        'outcome': 'denied_scope',
        'input': {'with_hud': false},
        'result_summary': 'camera scope not granted',
        'duration_ms': 12,
      });
      expect(e.id, '42');
      expect(e.assistant, 'ChatGPT');
      expect(e.provider, AiProvider.chatgpt);
      expect(e.action, 'take_photo');
      expect(e.result, 'denied_scope');
      expect(e.isOk, isFalse);
      expect(e.detail, 'camera scope not granted');
      expect(e.durationMs, 12);
    });

    test('ok outcome', () {
      final e = AiAuditEntry.fromJson(
          {'ts': '2026-11-06T10:05:00Z', 'tool': 'get_summary', 'outcome': 'ok'});
      expect(e.isOk, isTrue);
      expect(e.action, 'get_summary');
    });
  });

  group('AgentTranscriptLine', () {
    test('relay frame: role agent → WIM-Z speaker', () {
      final line = AgentTranscriptLine.fromEvent({
        'dog_id': 'dog_1',
        'role': 'agent',
        'text': 'Elsa had a quiet morning.',
        'ts': '2026-11-06T10:00:00Z',
      })!;
      expect(line.speaker, 'WIM-Z');
      expect(line.isUser, isFalse);
      expect(line.dogId, 'dog_1');
    });

    test('user role', () {
      final line = AgentTranscriptLine.fromEvent({'role': 'user', 'text': 'Hi'})!;
      expect(line.isUser, isTrue);
      expect(line.speaker, 'Owner');
    });
  });

  group('SoundSlot', () {
    test('relay row: builtin false = custom, kind song → song group', () {
      final s = SoundSlot.fromRelay({
        'id': 'song_my_tune',
        'kind': 'song',
        'label': 'My tune',
        'builtin': false,
        'file': 'song_my_tune.mp3',
        'url': '/api/sounds/file/dog_1/song_my_tune',
      })!;
      expect(s.custom, isTrue);
      expect(s.kind, SoundKind.song);
      expect(s.group, SoundGroup.song);
      expect(s.label, 'My tune');
      final b = SoundSlot.fromRelay({'id': 'chime', 'kind': 'sound', 'label': '', 'builtin': true, 'file': 'chime.wav'})!;
      expect(b.custom, isFalse);
      expect(b.label, isNull);
      expect(b.group, SoundGroup.cue);
    });

    test('robot row: group/stem addressing', () {
      final s = SoundSlot.fromRobot({'stem': 'good_dog', 'override': true}, groupKey: 'praise')!;
      expect(s.id, 'praise/good_dog');
      expect(s.robotGroup, 'praise');
      expect(s.stem, 'good_dog');
      expect(s.custom, isTrue);
      expect(s.group, SoundGroup.treat);
    });

    test('song id from filename matches the relay id pattern', () {
      final id = soundIdFromFilename('My Calm Song (v2).mp3');
      expect(id, 'song_my_calm_song_v2');
      expect(RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id), isTrue);
    });

    test('default catalog is the relay builtin set', () {
      expect(kDefaultSoundCatalog.map((s) => s.id),
          ['chime', 'whistle', 'shush', 'good_dog', 'song_calm_01', 'song_calm_02']);
    });
  });

  group('NotificationEvent attachments', () {
    test('digs image_url / clip_url from nested payloads', () {
      expect(attachmentImageUrl({'data': {'image_url': '/api/media/download/a.jpg'}}),
          isNotNull);
      expect(attachmentClipUrl({'payload': {'clip_url': '/api/media/download/a.mp4'}}),
          isNotNull);
      expect(attachmentImageUrl({'data': {}}), isNull);
    });

    test('missionDraft type is appended last (never reorder)', () {
      expect(NotificationEventType.values.last, NotificationEventType.missionDraft);
    });
  });
}
