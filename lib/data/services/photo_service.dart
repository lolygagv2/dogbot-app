import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/conn_trace.dart';
import '../../core/utils/time_utils.dart';

/// Model for a captured photo
class CapturedPhoto {
  final String id;
  final String filename;
  final String localPath;
  final DateTime timestamp;
  final bool savedToGallery;

  /// Relay gallery id (`photo_cmd_…`) when this photo was recorded by the
  /// relay (voice agent / Claude connector / POST command) rather than taken
  /// by the app itself. Doubles as the dedupe key. [[relay brief 2026-11-07]]
  final String? relayId;

  /// Dog the relay attributed the photo to. Null for app-taken photos.
  final String? dogId;

  CapturedPhoto({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.timestamp,
    this.savedToGallery = false,
    this.relayId,
    this.dogId,
  });

  /// "Taken by WIM-Z assistant": every relay-recorded robot photo id starts
  /// with `photo_cmd_`.
  bool get isAssistantPhoto => relayId?.startsWith('photo_cmd_') ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'localPath': localPath,
        'timestamp': timestamp.toIso8601String(),
        'savedToGallery': savedToGallery,
        if (relayId != null) 'relayId': relayId,
        if (dogId != null) 'dogId': dogId,
      };

  factory CapturedPhoto.fromJson(Map<String, dynamic> json) {
    return CapturedPhoto(
      id: json['id'] as String,
      filename: json['filename'] as String,
      localPath: json['localPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      savedToGallery: json['savedToGallery'] as bool? ?? false,
      relayId: json['relayId']?.toString(),
      dogId: json['dogId']?.toString(),
    );
  }
}

/// Sidecar record for a relay-recorded photo, keyed by relay id in
/// `relay_photos.json` next to the image files. Lets the gallery dedupe
/// against the relay (part 1 + 2 of the brief share the id), label the photo,
/// and compute the per-dog `since` watermark for catch-up.
class _RelayPhotoRecord {
  final String filename;
  final String dogId;
  final DateTime capturedAt;

  /// Tombstone: the user deleted this photo in the viewer. Kept so a later
  /// catch-up (whose `since` may sit before this capture) doesn't resurrect it.
  final bool deleted;
  const _RelayPhotoRecord({
    required this.filename,
    required this.dogId,
    required this.capturedAt,
    this.deleted = false,
  });

  _RelayPhotoRecord asDeleted() => _RelayPhotoRecord(
      filename: filename, dogId: dogId, capturedAt: capturedAt, deleted: true);

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'dogId': dogId,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        if (deleted) 'deleted': true,
      };

  static _RelayPhotoRecord? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final filename = raw['filename']?.toString();
    final dogId = raw['dogId']?.toString();
    final captured = DateTime.tryParse(raw['capturedAt']?.toString() ?? '');
    if (filename == null || dogId == null || captured == null) return null;
    return _RelayPhotoRecord(
      filename: filename,
      dogId: dogId,
      capturedAt: captured.toLocal(),
      deleted: raw['deleted'] == true,
    );
  }
}

/// Service for managing captured photos
class PhotoService {
  static PhotoService? _instance;
  static PhotoService get instance => _instance ??= PhotoService._();

  PhotoService._();

  Directory? _photosDir;

  static const String _relayIndexFile = 'relay_photos.json';

  /// relay id → record. Loaded once in [init]; written through on change.
  final Map<String, _RelayPhotoRecord> _relayIndex = {};
  bool _relayIndexLoaded = false;

  /// Initialize the photo service
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${appDir.path}/wimz_photos');
    if (!await _photosDir!.exists()) {
      await _photosDir!.create(recursive: true);
    }
    await _loadRelayIndex();
  }

  Future<void> _loadRelayIndex() async {
    if (_relayIndexLoaded) return;
    _relayIndexLoaded = true;
    try {
      final f = File('${_photosDir!.path}/$_relayIndexFile');
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is Map) {
        raw.forEach((k, v) {
          final rec = _RelayPhotoRecord.fromJson(v);
          if (rec != null) _relayIndex[k.toString()] = rec;
        });
      }
      connTrace('relay-photos-index', 'loaded ${_relayIndex.length}');
    } catch (e) {
      // Index is a cache over the files; a corrupt one just means we
      // re-download the 7-day window once. Surface it, don't swallow.
      connTrace('relay-photos-index-error', 'load: $e');
    }
  }

  Future<void> _saveRelayIndex() async {
    try {
      final f = File('${_photosDir!.path}/$_relayIndexFile');
      final out = _relayIndex.map((k, v) => MapEntry(k, v.toJson()));
      await f.writeAsString(jsonEncode(out), flush: true);
    } catch (e) {
      connTrace('relay-photos-index-error', 'save: $e');
    }
  }

  /// True when a relay photo with this id is already in the gallery.
  Future<bool> hasRelayPhoto(String relayId) async {
    await photosDirectory;
    final rec = _relayIndex[relayId];
    if (rec == null) return false;
    // A tombstoned (user-deleted) photo counts as present so catch-up never
    // brings it back. Otherwise trust the file, not the index: if the file
    // vanished (storage cleanup) let catch-up restore it.
    if (rec.deleted) return true;
    return File('${_photosDir!.path}/${rec.filename}').exists();
  }

  /// Newest `captured_at` saved for [dogId] — the catch-up `since` value.
  /// Null on first run for that dog.
  Future<DateTime?> newestRelayCaptureFor(String dogId) async {
    await photosDirectory;
    DateTime? newest;
    for (final rec in _relayIndex.values) {
      if (rec.dogId != dogId) continue;
      if (newest == null || rec.capturedAt.isAfter(newest)) {
        newest = rec.capturedAt;
      }
    }
    return newest;
  }

  /// Save a relay-recorded photo's bytes under [relayId] for [dogId]. The
  /// local file is named after the relay id so the id is also the filename.
  /// Copies into the phone's gallery (the relay keeps the image 7 days only).
  Future<CapturedPhoto> saveRelayPhoto({
    required String relayId,
    required String dogId,
    required Uint8List bytes,
    DateTime? capturedAt,
    bool saveToGallery = true,
  }) async {
    final dir = await photosDirectory;
    final captured = capturedAt ?? DateTime.now();
    final safeId = relayId.replaceAll(RegExp(r'[^\w.-]'), '_');
    final filename = '$safeId.jpg';
    final localPath = '${dir.path}/$filename';

    final file = File(localPath);
    await file.writeAsBytes(bytes, flush: true);
    // getPhotos() orders by mtime; stamp the real capture time so a
    // catch-up batch sorts by when the robot took it, not when we fetched.
    try {
      await file.setLastModified(captured);
    } catch (e) {
      connTrace('relay-photos-save', 'setLastModified failed: $e');
    }

    bool savedToGallery = false;
    if (saveToGallery) {
      try {
        await Gal.putImageBytes(bytes, album: 'WIMZ');
        savedToGallery = true;
      } catch (e) {
        connTrace('relay-photos-save', 'gallery copy failed: $e');
      }
    }

    _relayIndex[relayId] = _RelayPhotoRecord(
        filename: filename, dogId: dogId, capturedAt: captured);
    await _saveRelayIndex();

    return CapturedPhoto(
      id: relayId,
      filename: filename,
      localPath: localPath,
      timestamp: captured,
      savedToGallery: savedToGallery,
      relayId: relayId,
      dogId: dogId,
    );
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
        await Gal.putImageBytes(Uint8List.fromList(bytes), album: 'WIMZ');
        savedToGallery = true;
        print('PhotoService: Saved to gallery');
      } catch (e) {
        print('PhotoService: Failed to save to gallery: $e');
      }
    }

    return CapturedPhoto(
      id: id,
      filename: finalFilename,
      localPath: localPath,
      timestamp: parseServerTimestamp(timestamp, fallback: now),
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

    // Reverse lookup filename → relay id for labelling + dog attribution.
    final byFilename = <String, MapEntry<String, _RelayPhotoRecord>>{
      for (final e in _relayIndex.entries) e.value.filename: e,
    };

    final photos = <CapturedPhoto>[];
    for (final file in files) {
      final stat = await (file as File).stat();
      final filename = file.path.split('/').last;
      final relay = byFilename[filename];
      photos.add(CapturedPhoto(
        id: relay?.key ?? stat.modified.millisecondsSinceEpoch.toString(),
        filename: filename,
        localPath: file.path,
        timestamp: relay?.value.capturedAt ?? stat.modified,
        relayId: relay?.key,
        dogId: relay?.value.dogId,
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
        final filename = localPath.split('/').last;
        // Tombstone relay rows so catch-up doesn't re-download a photo the
        // user deliberately removed.
        var changed = false;
        for (final e in _relayIndex.entries.toList()) {
          if (e.value.filename == filename && !e.value.deleted) {
            _relayIndex[e.key] = e.value.asDeleted();
            changed = true;
          }
        }
        if (changed) await _saveRelayIndex();
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
