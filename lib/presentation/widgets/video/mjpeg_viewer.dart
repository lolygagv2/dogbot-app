import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
              const SizedBox(height: 8),
              Text(
                'Video unavailable',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 4),
              Text(
                streamUrl,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            ],
          ),
        );
      },
      loading: (context) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 8),
              Text('Connecting to camera...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        );
      },
    );
  }
}
