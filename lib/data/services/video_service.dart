import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/dio_client.dart';
import '../../core/utils/time_utils.dart';

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

/// Service for downloading and saving captured videos to gallery
class VideoService {
  static VideoService? _instance;
  static VideoService get instance => _instance ??= VideoService._();

  VideoService._();

  Directory? _videosDir;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120),
  ));

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

  /// Download video from URL and save to gallery
  Future<CapturedVideo> downloadAndSaveVideo({
    required String downloadUrl,
    String? filename,
    String? timestamp,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await videosDirectory;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';

    final cleanFilename = (filename ?? 'wimz_video_$id')
        .replaceAll(RegExp(r'[^\w.-]'), '_');
    final finalFilename = cleanFilename.endsWith('.mp4')
        ? cleanFilename
        : '$cleanFilename.mp4';

    final localPath = '${dir.path}/$finalFilename';

    // Resolve relative URLs against robot base URL
    String resolvedUrl = downloadUrl;
    if (downloadUrl.startsWith('/')) {
      final baseUrl = DioClient.instance.options.baseUrl;
      resolvedUrl = '$baseUrl$downloadUrl';
    }

    print('VideoService: Downloading from $resolvedUrl');
    print('VideoService: Saving to $localPath');

    // Download with progress
    await _dio.download(
      resolvedUrl,
      localPath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final file = File(localPath);
    final fileSize = await file.length();
    print('VideoService: Downloaded $fileSize bytes');

    if (fileSize < 100) {
      throw Exception('Downloaded file is too small ($fileSize bytes)');
    }

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
      timestamp: parseServerTimestamp(timestamp, fallback: now),
      savedToGallery: savedToGallery,
    );
  }
}
