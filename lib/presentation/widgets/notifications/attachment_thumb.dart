import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Thumbnail for a still / clip attached to a feed event. Tap opens a
/// full-screen viewer (a dialog — not a navigation level).
class AttachmentThumb extends StatelessWidget {
  final String? imageUrl;
  final String? clipUrl;
  final double size;

  const AttachmentThumb({
    super.key,
    this.imageUrl,
    this.clipUrl,
    this.size = 56,
  });

  bool get hasMedia => imageUrl != null || clipUrl != null;

  @override
  Widget build(BuildContext context) {
    if (!hasMedia) return const SizedBox.shrink();
    final w = context.wimz;
    return GestureDetector(
      onTap: () => showAttachmentViewer(context,
          imageUrl: imageUrl, clipUrl: clipUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(context),
                  loadingBuilder: (c, child, p) =>
                      p == null ? child : _placeholder(context),
                )
              else
                _placeholder(context),
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

  Widget _placeholder(BuildContext context) => Container(
        color: context.wimz.surfaceSunken,
        child: Icon(
          clipUrl != null ? Icons.videocam : Icons.image,
          color: context.wimz.inkMuted,
          size: 20,
        ),
      );
}

Future<void> showAttachmentViewer(
  BuildContext context, {
  String? imageUrl,
  String? clipUrl,
}) {
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
                  ? _ClipPlayer(url: clipUrl)
                  : InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                            ctx.l10n.attachmentOpenFailed,
                            style: TextStyle(color: ctx.wimz.onVideo),
                          ),
                        ),
                      ),
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
  const _ClipPlayer({required this.url});

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
    if (_failed) {
      return Center(
        child: Text(
          context.l10n.attachmentOpenFailed,
          style: TextStyle(color: context.wimz.onVideo),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
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
