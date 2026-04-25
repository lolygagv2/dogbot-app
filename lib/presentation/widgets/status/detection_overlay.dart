import 'package:flutter/material.dart';

import '../../../data/models/telemetry.dart';
import '../../theme/app_theme.dart';

/// Stable per-dog color so the same dog always renders with the same color
/// across the session. Hash the trackKey into the existing chip palette.
Color _colorForDog(Detection d) {
  // Theme palette of distinguishable colors. Keep small so two dogs are
  // unlikely to collide in practice.
  const palette = <Color>[
    Color(0xFF00E5FF), // cyan (primary)
    Color(0xFFFFC400), // amber
    Color(0xFFFF4081), // pink
    Color(0xFF76FF03), // lime
    Color(0xFFB388FF), // purple
    Color(0xFFFF6E40), // orange
  ];
  final idx = d.trackKey.hashCode.abs() % palette.length;
  return palette[idx];
}

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

    // C5: prefer per-dog color so multiple boxes are visually distinguishable.
    // Behavior color is still used as a hint when the dog is unidentified.
    final color = detection.dogId != null
        ? _colorForDog(detection)
        : AppTheme.getBehaviorColor(detection.behavior);

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
              '${detection.displayName.isNotEmpty ? "${detection.displayName} • " : ""}${AppTheme.getBehaviorDisplayName(detection.behavior)} ${((detection.confidence ?? 0) * 100).toInt()}%',
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

/// C5: Renders one [DetectionOverlay] per visible dog. Pass the live map
/// from `allDetectionsProvider`.
class MultiDetectionOverlay extends StatelessWidget {
  final Map<String, Detection> detections;
  final Size videoSize;

  const MultiDetectionOverlay({
    super.key,
    required this.detections,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        for (final d in detections.values)
          DetectionOverlay(detection: d, videoSize: videoSize),
      ],
    );
  }
}
