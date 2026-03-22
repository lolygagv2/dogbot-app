import 'dart:convert';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Model for a captured video
class CapturedVideo {
  final String id;
  final String filename;
  final String localPath;
  final DateTime timestamp;
  final bool savedToGallery;

  CapturedVideo({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.timestamp,
    this.savedToGallery = false,
  });
}

/// Service for saving captured videos to gallery
class VideoService {
  static VideoService? _instance;
  static VideoService get instance => _instance ??= VideoService._();

  VideoService._();

  Directory? _videosDir;

  Future<void> init() async {
    final appDir = await getTemporaryDirectory();
    _videosDir = Directory('${appDir.path}/wimz_videos');
    if (!await _videosDir!.exists()) {
      await _videosDir!.create(recursive: true);
    }
  }

  Future<Directory> get videosDirectory async {
    if (_videosDir == null) {
      await init();
    }
    return _videosDir!;
  }

  /// Save video from base64 data to gallery
  Future<CapturedVideo> saveVideo({
    required String base64Data,
    required String filename,
    String? timestamp,
  }) async {
    final dir = await videosDirectory;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';

    final cleanFilename = filename.replaceAll(RegExp(r'[^\w.-]'), '_');
    final finalFilename = cleanFilename.endsWith('.mp4')
        ? cleanFilename
        : '${cleanFilename}_$id.mp4';

    final localPath = '${dir.path}/$finalFilename';

    // Decode and save to temp file
    final bytes = base64Decode(base64Data);
    final file = File(localPath);
    await file.writeAsBytes(bytes);

    print('VideoService: Saved video to $localPath (${bytes.length} bytes)');

    // Save to gallery
    bool savedToGallery = false;
    try {
      await Gal.putVideo(localPath, album: 'WIMZ');
      savedToGallery = true;
      print('VideoService: Saved to gallery');
    } catch (e) {
      print('VideoService: Failed to save to gallery: $e');
    }

    return CapturedVideo(
      id: id,
      filename: finalFilename,
      localPath: localPath,
      timestamp: timestamp != null ? DateTime.tryParse(timestamp) ?? now : now,
      savedToGallery: savedToGallery,
    );
  }
}
