import 'package:flutter/material.dart';

import '../../../data/models/telemetry.dart';
import '../../theme/app_theme.dart';

class DetectionOverlay extends StatelessWidget {
  final Detection detection;
  final Size videoSize;

  const DetectionOverlay({
    super.key,
    required this.detection,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context) {
    if (!detection.detected || detection.bbox == null) {
      return const SizedBox.shrink();
    }

    final bbox = detection.bbox!;
    if (bbox.length < 4) return const SizedBox.shrink();

    final color = AppTheme.getBehaviorColor(detection.behavior);

    return Positioned(
      left: bbox[0] * videoSize.width,
      top: bbox[1] * videoSize.height,
      width: bbox[2] * videoSize.width,
      height: bbox[3] * videoSize.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              '${detection.behavior ?? "dog"} ${((detection.confidence ?? 0) * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
