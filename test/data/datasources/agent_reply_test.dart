import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/datasources/agent_api.dart';

/// POST /agent/utterance reply shape (relay brief 2026-11-06 §6).
void main() {
  group('AgentReply', () {
    test('parses the relay reply with unix expires_at and tool lists', () {
      final r = AgentReply.fromJson({
        'text_in': 'How was Elsa today?',
        'text_out': 'Quiet morning, two treats.',
        'audio_url': 'https://api.wimzai.com/agent/audio/abc.mp3',
        'clip_id': 'abc',
        'expires_at': 1765300000,
        'tools_used': ['get_day_summary'],
        'refused': [],
      });
      expect(r.textIn, 'How was Elsa today?');
      expect(r.textOut, 'Quiet morning, two treats.');
      expect(r.audioUrl, endsWith('abc.mp3'));
      expect(r.clipId, 'abc');
      expect(r.expiresAt, isNotNull);
      expect(r.expiresAt!.year, 2025);
      expect(r.toolsUsed, ['get_day_summary']);
      expect(r.refused, isEmpty);
    });

    test('refused entries may be strings or {tool, reason} maps', () {
      final r = AgentReply.fromJson({
        'text_out': 'I can’t do that.',
        'refused': [
          'camera scope not granted',
          {'tool': 'go_to', 'reason': 'unsupported'},
        ],
      });
      expect(r.refused, ['camera scope not granted', 'unsupported']);
      expect(r.textIn, isNull);
      expect(r.audioUrl, isNull);
    });

    test('empty strings collapse to null', () {
      final r = AgentReply.fromJson({'text_in': '', 'audio_url': ''});
      expect(r.textIn, isNull);
      expect(r.audioUrl, isNull);
    });
  });
}
