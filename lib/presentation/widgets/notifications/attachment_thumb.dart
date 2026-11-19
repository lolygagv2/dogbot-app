import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// One event still. Loads [authedUrl] (the relay's per-event photo endpoint,
/// with [headers]) first; if that fails for any reason other than "expired"
/// or "no photo", falls back to [directUrl] (the record's own `image_url`).
///
/// 410 photo_expired → [expired]; 404 no_photo_for_event → [onMissing] and
/// nothing drawn; anything else → [failed].
class EventStill extends StatefulWidget {
  final String? authedUrl;
  final Map<String, String>? headers;
  final String? directUrl;
  final BoxFit fit;

  /// Decode width in physical pixels (lists: thumbnail size, not 1920 wide).
  final int? cacheWidth;
  final WidgetBuilder loading;
  final WidgetBuilder failed;
  final WidgetBuilder expired;
  final VoidCallback? onMissing;

  const EventStill({
    super.key,
    this.authedUrl,
    this.headers,
    this.directUrl,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    required this.loading,
    required this.failed,
    required this.expired,
    this.onMissing,
  });

  @override
  State<EventStill> createState() => _EventStillState();
}

enum _StillStage { authed, direct, expired, missing, failed }

class _EventStillState extends State<EventStill> {
  late _StillStage _stage = _first();
  bool _moving = false;

  _StillStage _first() => widget.authedUrl != null && widget.headers != null
      ? _StillStage.authed
      : widget.directUrl != null
          ? _StillStage.direct
          : _StillStage.failed;

  @override
  void didUpdateWidget(EventStill old) {
    super.didUpdateWidget(old);
    if (old.authedUrl != widget.authedUrl || old.directUrl != widget.directUrl) {
      _stage = _first();
      _moving = false;
    }
  }

  /// Called from an errorBuilder (during build): move on after the frame.
  void _onError(Object error) {
    if (_moving) return;
    _moving = true;
    final code = error is NetworkImageLoadException ? error.statusCode : null;
    final next = _stage == _StillStage.authed
        ? (code == 410
            ? _StillStage.expired
            : code == 404
                ? _StillStage.missing
                : widget.directUrl != null
                    ? _StillStage.direct
                    : _StillStage.failed)
        : _StillStage.failed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _stage = next;
        _moving = false;
      });
      if (next == _StillStage.missing) widget.onMissing?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _StillStage.expired:
        return widget.expired(context);
      case _StillStage.missing:
        return const SizedBox.shrink();
      case _StillStage.failed:
        return widget.failed(context);
      case _StillStage.authed:
      case _StillStage.direct:
        final authed = _stage == _StillStage.authed;
        return Image.network(
          authed ? widget.authedUrl! : widget.directUrl!,
          key: ValueKey(_stage),
          headers: authed ? widget.headers : null,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (c, e, __) {
            _onError(e);
            return widget.loading(c);
          },
          loadingBuilder: (c, child, p) =>
              p == null ? child : widget.loading(c),
        );
    }
  }
}

/// Thumbnail for a still / clip attached to a feed event. Tap opens a
/// full-screen viewer (a dialog — not a navigation level). A clip gets a
/// play badge; nothing is drawn when the event has neither.
class AttachmentThumb extends StatefulWidget {
  final String? imageUrl;
  final String? clipUrl;

  /// The event's authenticated photo endpoint + its headers (see
  /// [EventStill]); [imageUrl] is then the fallback.
  final String? authedImageUrl;
  final Map<String, String>? imageHeaders;
  final double size;

  const AttachmentThumb({
    super.key,
    this.imageUrl,
    this.clipUrl,
    this.authedImageUrl,
    this.imageHeaders,
    this.size = 56,
  });

  @override
  State<AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<AttachmentThumb> {
  /// The relay says the event has no photo (404).
  bool _noPhoto = false;

  @override
  void didUpdateWidget(AttachmentThumb old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl ||
        old.authedImageUrl != widget.authedImageUrl) {
      _noPhoto = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl != null && !_noPhoto;
    final clipUrl = widget.clipUrl;
    if (!hasImage && clipUrl == null) return const SizedBox.shrink();
    final w = context.wimz;
    final size = widget.size;
    return GestureDetector(
      onTap: () => showAttachmentViewer(
        context,
        imageUrl: hasImage ? widget.imageUrl : null,
        clipUrl: clipUrl,
        authedImageUrl: hasImage ? widget.authedImageUrl : null,
        imageHeaders: widget.imageHeaders,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                EventStill(
                  authedUrl: widget.authedImageUrl,
                  headers: widget.imageHeaders,
                  directUrl: widget.imageUrl,
                  cacheWidth:
                      (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  loading: (c) => _placeholder(c, Icons.image),
                  failed: (c) => _placeholder(c, Icons.image),
                  expired: (c) =>
                      _placeholder(c, Icons.hide_image_outlined),
                  onMissing: () => setState(() => _noPhoto = true),
                )
              else
                _placeholder(context, Icons.videocam),
              if (clipUrl != null)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: w.scrim(0.54),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.play_arrow,
                        color: w.onVideo, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) => Container(
        color: context.wimz.surfaceSunken,
        child: Icon(icon, color: context.wimz.inkMuted, size: 20),
      );
}

/// Full-screen still, or the clip (streamed mp4) with the still as its
/// poster frame.
Future<void> showAttachmentViewer(
  BuildContext context, {
  String? imageUrl,
  String? clipUrl,
  String? authedImageUrl,
  Map<String, String>? imageHeaders,
}) {
  Widget still(BuildContext ctx, {required bool poster}) {
    Widget note(String text) => poster
        ? const SizedBox.shrink()
        : Center(
            child: Text(text, style: TextStyle(color: ctx.wimz.onVideo)));
    return EventStill(
      authedUrl: authedImageUrl,
      headers: imageHeaders,
      directUrl: imageUrl,
      fit: BoxFit.contain,
      loading: (_) => poster
          ? const SizedBox.shrink()
          : const Center(child: CircularProgressIndicator()),
      failed: (c) => note(c.l10n.attachmentOpenFailed),
      expired: (c) => note(c.l10n.attachmentPhotoExpired),
    );
  }

  // Always a dark ground (photo / clip viewer): on-video tokens throughout.
  return showDialog(
    context: context,
    barrierColor: context.wimz.scrim(0.87),
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: ctx.wimz.brandInk,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: clipUrl != null
                  ? _ClipPlayer(
                      url: clipUrl,
                      poster:
                          imageUrl == null ? null : still(ctx, poster: true),
                    )
                  : InteractiveViewer(
                      child: Center(child: still(ctx, poster: false)),
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: ctx.wimz.onVideo),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClipPlayer extends StatefulWidget {
  final String url;

  /// The event's still, shown until the mp4 has its first frame (and behind
  /// the "no longer available" text if it never loads).
  final Widget? poster;
  const _ClipPlayer({required this.url, this.poster});

  @override
  State<_ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<_ClipPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !_ready) {
      final w = context.wimz;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.poster != null) widget.poster!,
          Center(
            child: _failed
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: w.scrim(0.54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.l10n.attachmentClipGone,
                      style: TextStyle(color: w.onVideo),
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }),
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio == 0
              ? 16 / 9
              : _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
