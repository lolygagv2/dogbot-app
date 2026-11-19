import 'notification_event.dart';

/// What the Events tab needs from one relay event record
/// (`GET /api/dogs/{dog}/events` row, or the `event` object of a live WS
/// `{type: event}` frame): its still / clip, and the settle detail.
///
/// The Events tab itself is fed by the relay's activity mirror, which only
/// copies `image_url` for bark episodes. Media for every other type (settle /
/// quiet check-in, intervention, treat, pacing …) is joined in from here by
/// `event_id` — the mirror row carries the same id.
class EventMedia {
  final String eventId;
  final String type; // bark_episode | settle | intervention | treat | …
  final String? imageUrl; // absolute
  final String? clipUrl; // absolute (mp4)

  /// `settle` only: `quiet_check` for a quiet check-in.
  final String? kind;

  /// Quiet check-in: minutes of quiet so far.
  final int? quietMin;

  const EventMedia({
    required this.eventId,
    required this.type,
    this.imageUrl,
    this.clipUrl,
    this.kind,
    this.quietMin,
  });

  bool get hasMedia => imageUrl != null || clipUrl != null;
  bool get isQuietCheck => type == 'settle' && kind == 'quiet_check';

  /// Worth caching: something the mirror row does not already say.
  bool get isUseful => hasMedia || isQuietCheck;

  /// Null when the row has no id. URLs are read from the row's top level or
  /// its `data` object, under any spelling [attachmentImageUrl] /
  /// [attachmentClipUrl] accept (`image_url`, `still_url`, `clip_url`,
  /// `video_url` …), and made absolute.
  static EventMedia? fromEvent(Map<String, dynamic> e) {
    final id = (e['event_id'] ?? e['id'])?.toString();
    if (id == null || id.isEmpty) return null;
    final data = e['data'] is Map
        ? (e['data'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final q = data['quiet_min'];
    return EventMedia(
      eventId: id,
      type: e['type']?.toString() ?? '',
      imageUrl: attachmentImageUrl(e),
      clipUrl: attachmentClipUrl(e),
      kind: data['kind']?.toString(),
      quietMin: q is num ? q.toInt() : int.tryParse('$q'),
    );
  }
}
