import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/event_media.dart';
import 'package:wimz_app/data/models/notification_event.dart';
import 'package:wimz_app/domain/providers/foreground_push_provider.dart';
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
        dogId: 'd1',
        type: 'settle',
        kind: 'quiet_check',
        quietMin: 30,
        imageUrl: 'https://x/a.jpg',
        clipUrl: 'https://x/a.mp4',
      ),
      l,
    );
    expect(joined.imageUrl, 'https://x/a.jpg');
    expect(joined.metadata?[kFeedPhotoUrlKey],
        'https://api.wimzai.com/api/dogs/d1/events/e1/photo');
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

  test('settle wording: after barking = settle_s; never "0 min"', () {
    NotificationEvent row(String id) => NotificationEvent(
          id: id,
          type: NotificationEventType.happy,
          timestamp: DateTime(2026, 11, 18, 11),
          title: 'Settled',
        );
    final after = EventMedia.fromEvent({
      'event_id': 's1',
      'type': 'settle',
      'data': {'episode_id': 'b1', 'settle_s': 560},
    })!;
    expect(after.isUseful, isTrue);
    final a = withEventMedia(row('s1'), after, l);
    expect(a.title, 'Settled');
    expect(a.subtitle, 'Settled after 10 min');

    final zero = withEventMedia(
        row('s2'),
        const EventMedia(
            eventId: 's2', type: 'settle', kind: 'quiet_check', quietMin: 0),
        l);
    expect(zero.title, 'Quiet check-in');
    expect(zero.subtitle, isNull);
  });

  test('photo endpoint URL encodes replay event ids; push carries it', () {
    expect(
      eventPhotoUrl('d1', 'replay:d1:2026-11-18:36'),
      'https://api.wimzai.com/api/dogs/d1/events/replay%3Ad1%3A2026-11-18%3A36/photo',
    );
    expect(eventPhotoUrl(null, 'e'), isNull);
    final push = ForegroundPush.fromParts(title: 'Bark', data: const {
      'event_id': 'e7',
      'dog_id': 'd1',
      'image_url': '/api/media/download/a.png',
      'clip_url': '',
    })!;
    expect(push.hasMedia, isTrue);
    expect(push.clipUrl, isNull);
    expect(push.photoUrl, 'https://api.wimzai.com/api/dogs/d1/events/e7/photo');
  });
}
