import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../domain/providers/foreground_push_provider.dart';
import '../../theme/app_theme.dart';

/// Shows foreground pushes as a banner above EVERY route (installed in the
/// MaterialApp builder, so it also covers full-screen routes like the demo
/// view). Carries the push's still, or the first frame of its clip.
/// Tap or the close button dismisses; it never navigates.
class PushBannerHost extends ConsumerStatefulWidget {
  final Widget child;
  const PushBannerHost({super.key, required this.child});

  static const showFor = Duration(seconds: 8);

  @override
  ConsumerState<PushBannerHost> createState() => _PushBannerHostState();
}

class _PushBannerHostState extends ConsumerState<PushBannerHost> {
  Timer? _hide;

  void _arm(ForegroundPush? p) {
    _hide?.cancel();
    if (p == null) return;
    _hide = Timer(PushBannerHost.showFor, () {
      if (!mounted) return;
      // Only clear the banner this timer was armed for.
      if (identical(ref.read(foregroundPushProvider), p)) _dismiss();
    });
  }

  void _dismiss() => ref.read(foregroundPushProvider.notifier).state = null;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ForegroundPush?>(foregroundPushProvider, (_, next) => _arm(next));
    final push = ref.watch(foregroundPushProvider);
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(0, -1), end: Offset.zero)
                    .animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: push == null
                  ? const SizedBox.shrink()
                  : _Banner(
                      key: ValueKey(push.receivedAt),
                      push: push,
                      onDismiss: _dismiss,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final ForegroundPush push;
  final VoidCallback onDismiss;
  const _Banner({super.key, required this.push, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    final hasMedia = push.imageUrl != null || push.clipUrl != null;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Material(
            color: w.surfaceRaised,
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onDismiss,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: w.line),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    if (hasMedia) ...[
                      _Thumb(imageUrl: push.imageUrl, clipUrl: push.clipUrl),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (push.title.isNotEmpty)
                            Text(
                              push.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: w.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (push.body.isNotEmpty)
                            Text(
                              push.body,
                              style: TextStyle(fontSize: 13, color: w.inkMuted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: w.inkMuted),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The still, or the clip's first frame with a play badge.
class _Thumb extends StatelessWidget {
  final String? imageUrl;
  final String? clipUrl;
  const _Thumb({this.imageUrl, this.clipUrl});

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    Widget placeholder() => Container(
          color: w.surfaceSunken,
          child: Icon(clipUrl != null ? Icons.videocam : Icons.image,
              color: w.inkMuted, size: 22),
        );
    return ClipRRect(
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
                errorBuilder: (_, __, ___) => placeholder(),
                loadingBuilder: (c, child, p) =>
                    p == null ? child : placeholder(),
              )
            else if (clipUrl != null)
              _ClipFrame(url: clipUrl!, placeholder: placeholder())
            else
              placeholder(),
            if (clipUrl != null)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                      color: w.scrim(0.54), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.play_arrow, color: w.onVideo, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// First frame of a clip (loaded, never played); placeholder until ready or
/// when the clip can't be opened.
class _ClipFrame extends StatefulWidget {
  final String url;
  final Widget placeholder;
  const _ClipFrame({required this.url, required this.placeholder});

  @override
  State<_ClipFrame> createState() => _ClipFrameState();
}

class _ClipFrameState extends State<_ClipFrame> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return widget.placeholder;
    final s = _c.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: s.width == 0 ? 16 : s.width,
        height: s.height == 0 ? 9 : s.height,
        child: VideoPlayer(_c),
      ),
    );
  }
}
