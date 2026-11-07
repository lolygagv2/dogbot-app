import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/relay_error.dart';
import '../../core/utils/time_utils.dart';

final dogPhotosApiProvider = Provider<DogPhotosApi>((ref) {
  return DogPhotosApi(ref.watch(dioClientProvider));
});

/// One row of `GET /api/dogs/{dog_id}/photos` (relay brief 2026-11-07):
/// {id, dog_id, photo_url, is_profile_photo, captured_at}
class RelayPhoto {
  final String id;
  final String dogId;

  /// Relative (`/api/dogs/…/media/x.jpg`) or, for POST-added photos, possibly
  /// a full external URL.
  final String photoUrl;
  final bool isProfilePhoto;
  final DateTime? capturedAt;

  const RelayPhoto({
    required this.id,
    required this.dogId,
    required this.photoUrl,
    this.isProfilePhoto = false,
    this.capturedAt,
  });

  /// Every relay-recorded robot photo id starts with `photo_cmd_`.
  bool get isAssistantPhoto => id.startsWith('photo_cmd_');

  static RelayPhoto? fromJson(dynamic raw, {required String dogId}) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final id = j['id']?.toString();
    final url = j['photo_url']?.toString();
    if (id == null || id.isEmpty || url == null || url.isEmpty) return null;
    return RelayPhoto(
      id: id,
      dogId: j['dog_id']?.toString() ?? dogId,
      photoUrl: url,
      isProfilePhoto: j['is_profile_photo'] == true,
      capturedAt: tryParseServerTimestamp(j['captured_at']?.toString()),
    );
  }
}

class RelayPhotoListResult {
  final List<RelayPhoto> photos;
  final String? error;

  /// 404 on the list route: relay has no photos slice.
  final bool unsupported;
  const RelayPhotoListResult(
      {this.photos = const [], this.error, this.unsupported = false});
}

/// Outcome of one media download.
enum RelayPhotoDownloadStatus {
  ok,

  /// 404 still_not_found — expired after 7 days. Never retry.
  gone,

  /// 403 — not this user's robot. Skip.
  forbidden,

  /// Network / 5xx — may retry on the next catch-up.
  failed,
}

class RelayPhotoDownload {
  final RelayPhotoDownloadStatus status;
  final Uint8List? bytes;
  final String? error;
  const RelayPhotoDownload(this.status, {this.bytes, this.error});
  bool get ok => status == RelayPhotoDownloadStatus.ok && bytes != null;
}

/// Relay photo gallery: list a dog's relay-recorded photos and fetch the
/// JPEG bytes with the app JWT.
class DogPhotosApi {
  final Dio _dio;
  DogPhotosApi(this._dio);

  /// `GET /api/dogs/{dog_id}/photos?since=<ISO 8601>` — newest first.
  /// [since] is sent as UTC; the relay returns only photos strictly after it.
  Future<RelayPhotoListResult> list({
    required String token,
    required String dogId,
    DateTime? since,
  }) async {
    try {
      final r = await _dio.get(
        ApiEndpoints.dogPhotos(dogId),
        queryParameters: {
          if (since != null) 'since': since.toUtc().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = r.data;
      // Lenient: the relay says a bare list; tolerate {photos: [...]} too.
      final rows = data is List
          ? data
          : (data is Map && data['photos'] is List)
              ? data['photos'] as List
              : const [];
      final photos = rows
          .map((e) => RelayPhoto.fromJson(e, dogId: dogId))
          .whereType<RelayPhoto>()
          .toList();
      return RelayPhotoListResult(photos: photos);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        connTrace('relay-photos-list', 'dog=$dogId 404 (not deployed)');
        return const RelayPhotoListResult(unsupported: true);
      }
      final msg = relayErrorMessage(e);
      connTrace('relay-photos-list-error', 'dog=$dogId status=$status $msg');
      return RelayPhotoListResult(error: msg);
    } catch (e) {
      connTrace('relay-photos-list-error', 'dog=$dogId $e');
      return RelayPhotoListResult(error: '$e');
    }
  }

  /// Download one photo by its relay path (`/api/dogs/{dog}/media/{file}` or
  /// a full URL) with the JWT. Relative paths resolve against the Dio base
  /// URL, i.e. the active relay host.
  Future<RelayPhotoDownload> download({
    required String token,
    required String url,
  }) async {
    try {
      final r = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final bytes = r.data;
      if (r.statusCode == 200 && bytes != null && bytes.isNotEmpty) {
        return RelayPhotoDownload(RelayPhotoDownloadStatus.ok,
            bytes: Uint8List.fromList(bytes));
      }
      return RelayPhotoDownload(RelayPhotoDownloadStatus.failed,
          error: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return const RelayPhotoDownload(RelayPhotoDownloadStatus.gone,
            error: 'expired');
      }
      if (status == 403) {
        return const RelayPhotoDownload(RelayPhotoDownloadStatus.forbidden,
            error: 'forbidden');
      }
      return RelayPhotoDownload(RelayPhotoDownloadStatus.failed,
          error: 'status=$status ${relayErrorMessage(e)}');
    } catch (e) {
      return RelayPhotoDownload(RelayPhotoDownloadStatus.failed, error: '$e');
    }
  }
}
