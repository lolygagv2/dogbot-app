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
                  errorBuilder: (_, __, ___) => _placeholder(),
                  loadingBuilder: (c, child, p) =>
                      p == null ? child : _placeholder(),
                )
              else
                _placeholder(),
              if (clipUrl != null)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surfaceLighter,
        child: Icon(
          clipUrl != null ? Icons.videocam : Icons.image,
          color: AppTheme.textTertiary,
          size: 20,
        ),
      );
}

Future<void> showAttachmentViewer(
  BuildContext context, {
  String? imageUrl,
  String? clipUrl,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
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
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
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
          style: const TextStyle(color: AppTheme.textSecondary),
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
