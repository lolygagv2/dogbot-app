import 'package:flutter/material.dart';

import '../../../data/models/telemetry.dart';
import '../../theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// Stable per-dog color so the same dog always renders with the same color
/// across the session. Hash the trackKey into the brand token palette (no
/// new hues); every box also prints the dog's name + behaviour label.
Color _colorForDog(BuildContext context, Detection d) {
  final palette = WimzStatus.dogPalette(context, onVideo: true);
  final idx = d.trackKey.hashCode.abs() % palette.length;
  return palette[idx];
}

/// Label ink that reads on [fill]: brand-ink on light fills, brand-white
/// on dark ones (no new hue).
Color _labelOn(BuildContext context, Color fill) {
  final w = context.wimz;
  return fill.computeLuminance() > 0.4 ? w.brandInk : w.brandWhite;
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
        ? _colorForDog(context, detection)
        : WimzStatus.behavior(context, detection.behavior, onVideo: true);
    final labelColor = _labelOn(context, color);

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
              '${detection.localizedDisplayName(context.l10n).isNotEmpty ? "${detection.localizedDisplayName(context.l10n)} • " : ""}${behaviorDisplayName(context.l10n, detection.behavior)} ${((detection.confidence ?? 0) * 100).toInt()}%',
              style: TextStyle(
                color: labelColor,
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
