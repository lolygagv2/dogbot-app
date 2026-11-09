import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/spec_records.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Chain REC confirmation surface: "the robot wrote your recording, here it
/// is." Renders one spec `media_asset` row (§4); the file itself lives on
/// the robot under /data/<rel_path> (§3).
///
/// To wire: show this from the record-stop flow once the robot persists the
/// file and reports its media_asset row. Save/Share stay honest until the
/// robot side of Chain REC ships a download endpoint.
class VideoSavedSheet extends StatelessWidget {
  final MediaAsset asset;
  final bool sampleData;

  const VideoSavedSheet({
    super.key,
    required this.asset,
    this.sampleData = false,
  });

  static Future<void> show(
    BuildContext context,
    MediaAsset asset, {
    bool sampleData = false,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => VideoSavedSheet(asset: asset, sampleData: sampleData),
    );
  }

  String get _duration {
    final ms = asset.durationMs;
    if (ms == null) return '—';
    final s = (ms / 1000).round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  String get _size {
    final b = asset.sizeBytes;
    if (b == null) return '—';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _notWiredYet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.videoSavedNotWired),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final robotPath = '/data/${asset.relPath}';
    final l = context.l10n;
    final w = context.wimz;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sampleData)
              Center(
                child: Text(
                  l.videoSavedSampleData,
                  style: TextStyle(
                    color: w.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: w.ink, size: 28),
                const SizedBox(width: 10),
                Text(
                  l.videoSavedTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l.videoSavedOnRobotAt,
              style: TextStyle(
                color: w.inkMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: robotPath));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.videoSavedPathCopied)),
                  );
                }
              },
              child: Text(
                robotPath,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: w.inkMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(w, _duration),
                _chip(w, _size),
                if (asset.width != null && asset.height != null)
                  _chip(w, '${asset.width}×${asset.height}'),
                if (asset.codec != null) _chip(w, asset.codec!.toUpperCase()),
                _chip(w, l.videoSavedRetention(asset.retentionClass)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _notWiredYet(context),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(l.videoSavedSaveToPhone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _notWiredYet(context),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(l.videoSavedShare),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(WimzColors w, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: w.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: w.line),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}
