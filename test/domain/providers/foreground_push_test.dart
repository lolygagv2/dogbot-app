import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/notification_event.dart'
    show attachmentBaseUrl;
import 'package:wimz_app/domain/providers/foreground_push_provider.dart';

/// Relay push payload (notify_service): notification {title, body, image?}
/// + data {type, dog_id, event_id, rule_id, image_url, clip_url}.
void main() {
  setUp(() => attachmentBaseUrl = 'https://relay.test');

  test('still push: relative data.image_url is made absolute', () {
    final p = ForegroundPush.fromParts(
      title: 'Bezik is barking',
      body: '3 barks in the living room',
      data: {
        'type': 'bark',
        'event_id': 'e1',
        'image_url': '/media/e1.jpg',
        'clip_url': '',
      },
    )!;
    expect(p.title, 'Bezik is barking');
    expect(p.imageUrl, 'https://relay.test/media/e1.jpg');
    expect(p.clipUrl, isNull);
    expect(p.eventId, 'e1');
  });

  test('clip push carries the clip and no still', () {
    final p = ForegroundPush.fromParts(
      title: 't',
      body: 'b',
      data: {'image_url': '', 'clip_url': '/media/e2.mp4'},
    )!;
    expect(p.imageUrl, isNull);
    expect(p.clipUrl, 'https://relay.test/media/e2.mp4');
  });

  test('falls back to the notification image; no media is fine', () {
    final withImage = ForegroundPush.fromParts(
        title: 't', notificationImage: 'https://cdn.test/x.jpg')!;
    expect(withImage.imageUrl, 'https://cdn.test/x.jpg');
    final plain = ForegroundPush.fromParts(title: 't', body: 'b')!;
    expect(plain.imageUrl, isNull);
    expect(plain.clipUrl, isNull);
  });

  test('data-only message with nothing to show → no banner', () {
    expect(ForegroundPush.fromParts(data: {'type': 'x'}), isNull);
  });
}
