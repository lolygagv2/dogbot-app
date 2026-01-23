import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

/// Model for a captured photo
class CapturedPhoto {
  final String id;
  final String filename;
  final String localPath;
  final DateTime timestamp;
  final bool savedToGallery;

  CapturedPhoto({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.timestamp,
    this.savedToGallery = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'localPath': localPath,
        'timestamp': timestamp.toIso8601String(),
        'savedToGallery': savedToGallery,
      };

  factory CapturedPhoto.fromJson(Map<String, dynamic> json) {
    return CapturedPhoto(
      id: json['id'] as String,
      filename: json['filename'] as String,
      localPath: json['localPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      savedToGallery: json['savedToGallery'] as bool? ?? false,
    );
  }
}

/// Service for managing captured photos
class PhotoService {
  static PhotoService? _instance;
  static PhotoService get instance => _instance ??= PhotoService._();

  PhotoService._();

  Directory? _photosDir;

  /// Initialize the photo service
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${appDir.path}/wimz_photos');
    if (!await _photosDir!.exists()) {
      await _photosDir!.create(recursive: true);
    }
  }

  /// Get the photos directory
  Future<Directory> get photosDirectory async {
    if (_photosDir == null) {
      await init();
    }
    return _photosDir!;
  }

  /// Save a photo from base64 data
  /// Returns the CapturedPhoto with local path
  Future<CapturedPhoto> savePhoto({
    required String base64Data,
    required String filename,
    String? timestamp,
    bool saveToGallery = true,
  }) async {
    final dir = await photosDirectory;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';

    // Clean filename and ensure jpg extension
    final cleanFilename = filename.replaceAll(RegExp(r'[^\w.-]'), '_');
    final finalFilename = cleanFilename.endsWith('.jpg') ||
            cleanFilename.endsWith('.png')
        ? cleanFilename
        : '${cleanFilename}_$id.jpg';

    final localPath = '${dir.path}/$finalFilename';

    // Decode and save locally
    final bytes = base64Decode(base64Data);
    final file = File(localPath);
    await file.writeAsBytes(bytes);

    print('PhotoService: Saved photo to $localPath');

    // Save to gallery if requested
    bool savedToGallery = false;
    if (saveToGallery) {
      try {
        final result = await ImageGallerySaver.saveImage(
          Uint8List.fromList(bytes),
          name: 'WIMZ_$id',
          quality: 100,
        );
        savedToGallery = result['isSuccess'] == true;
        print('PhotoService: Gallery save result: $result');
      } catch (e) {
        print('PhotoService: Failed to save to gallery: $e');
      }
    }

    return CapturedPhoto(
      id: id,
      filename: finalFilename,
      localPath: localPath,
      timestamp: timestamp != null ? DateTime.tryParse(timestamp) ?? now : now,
      savedToGallery: savedToGallery,
    );
  }

  /// Get all saved photos
  Future<List<CapturedPhoto>> getPhotos() async {
    final dir = await photosDirectory;
    final files = await dir
        .list()
        .where((f) => f is File && (f.path.endsWith('.jpg') || f.path.endsWith('.png')))
        .toList();

    final photos = <CapturedPhoto>[];
    for (final file in files) {
      final stat = await (file as File).stat();
      final filename = file.path.split('/').last;
      photos.add(CapturedPhoto(
        id: stat.modified.millisecondsSinceEpoch.toString(),
        filename: filename,
        localPath: file.path,
        timestamp: stat.modified,
      ));
    }

    // Sort by newest first
    photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return photos;
  }

  /// Delete a photo by path
  Future<bool> deletePhoto(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        print('PhotoService: Deleted photo at $localPath');
        return true;
      }
    } catch (e) {
      print('PhotoService: Failed to delete photo: $e');
    }
    return false;
  }

  /// Get photo bytes for sharing
  Future<Uint8List?> getPhotoBytes(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('PhotoService: Failed to read photo: $e');
    }
    return null;
  }
}
