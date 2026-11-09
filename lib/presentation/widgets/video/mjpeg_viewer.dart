import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

class MjpegViewer extends StatelessWidget {
  final String streamUrl;
  final BoxFit fit;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Mjpeg(
      stream: streamUrl,
      isLive: true,
      fit: fit,
      timeout: const Duration(seconds: 10),
      error: (context, error, stack) {
        final onVideo = context.wimz.onVideo;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off,
                  size: 48, color: onVideo.withValues(alpha: 0.54)),
              const SizedBox(height: 8),
              Text(
                context.l10n.mjpegUnavailable,
                style: TextStyle(color: onVideo.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 4),
              Text(
                streamUrl,
                style: TextStyle(
                    color: onVideo.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
        );
      },
      loading: (context) {
        final muted = context.wimz.onVideo.withValues(alpha: 0.54);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: muted),
              const SizedBox(height: 8),
              Text(context.l10n.mjpegConnecting,
                  style: TextStyle(color: muted)),
            ],
          ),
        );
      },
    );
  }
}
