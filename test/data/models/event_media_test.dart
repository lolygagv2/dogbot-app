import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/event_media.dart';
import 'package:wimz_app/data/models/notification_event.dart';
import 'package:wimz_app/domain/providers/notifications_provider.dart';
import 'package:wimz_app/l10n/app_localizations.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('settle / quiet check-in record: still + clip from data, absolute', () {
    final m = EventMedia.fromEvent({
      'event_id': 'e1',
      'type': 'settle',
      'data': {
        'kind': 'quiet_check',
        'quiet_min': 30,
        'image_url': '/api/media/download/a.jpg',
        'clip_url': '/api/media/download/a.mp4',
      },
    })!;
    expect(m.imageUrl, 'https://api.wimzai.com/api/media/download/a.jpg');
    expect(m.clipUrl, 'https://api.wimzai.com/api/media/download/a.mp4');
    expect(m.isQuietCheck, isTrue);
    expect(m.quietMin, 30);
    expect(m.isUseful, isTrue);
  });

  test('record with no media and no settle detail is not worth caching', () {
    final m = EventMedia.fromEvent({
      'event_id': 'e2',
      'type': 'treat',
      'data': {'count': 1, 'image_url': ''},
    })!;
    expect(m.hasMedia, isFalse);
    expect(m.isUseful, isFalse);
    expect(EventMedia.fromEvent({'type': 'treat'}), isNull);
  });

  test('joins onto the mirror row by payload event_id; row media wins', () {
    final row = NotificationEvent(
      id: 'row-1',
      type: NotificationEventType.happy,
      timestamp: DateTime(2026, 11, 18, 11),
      title: 'Settled',
      metadata: const {'action': 'settled', 'event_id': 'e1'},
    );
    expect(feedEventKey(row), 'e1');

    final joined = withEventMedia(
      row,
      const EventMedia(
        eventId: 'e1',
        type: 'settle',
        kind: 'quiet_check',
        quietMin: 30,
        imageUrl: 'https://x/a.jpg',
        clipUrl: 'https://x/a.mp4',
      ),
      l,
    );
    expect(joined.imageUrl, 'https://x/a.jpg');
    expect(joined.clipUrl, 'https://x/a.mp4');
    expect(joined.title, 'Quiet check-in');
    expect(joined.subtitle, 'Quiet for 30 min');

    final bark = NotificationEvent(
      id: 'e9',
      type: NotificationEventType.bark,
      timestamp: DateTime(2026, 11, 18, 12),
      title: 'Barking Detected',
      imageUrl: 'https://x/own.jpg',
    );
    expect(feedEventKey(bark), 'e9');
    final b = withEventMedia(
      bark,
      const EventMedia(
          eventId: 'e9',
          type: 'bark_episode',
          imageUrl: 'https://x/other.jpg',
          clipUrl: 'https://x/b.mp4'),
      l,
    );
    expect(b.imageUrl, 'https://x/own.jpg');
    expect(b.clipUrl, 'https://x/b.mp4');
    expect(b.title, 'Barking Detected');
  });
}
