import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_clip.freezed.dart';
part 'video_clip.g.dart';

/// A recorded video clip from the robot
@freezed
class VideoClip with _$VideoClip {
  const VideoClip._();

  const factory VideoClip({
    required String id,
    required String url,
    required DateTime timestamp,
    required Duration duration,
    String? thumbnailUrl,
    String? dogId,
    String? missionId,
    @Default([]) List<String> tags,
    @Default([]) List<VideoEvent> events,
    @Default(false) bool isFavorite,
    @Default(false) bool isShared,
  }) = _VideoClip;

  factory VideoClip.fromJson(Map<String, dynamic> json) =>
      _$VideoClipFromJson(json);

  /// Create from API response
  factory VideoClip.fromApiResponse(Map<String, dynamic> data) {
    return VideoClip(
      id: data['id'] as String? ?? '',
      url: data['url'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
      duration: Duration(
        seconds: data['duration_seconds'] as int? ??
            data['durationSeconds'] as int? ?? 0,
      ),
      thumbnailUrl: data['thumbnail_url'] as String? ??
          data['thumbnailUrl'] as String?,
      dogId: data['dog_id'] as String? ?? data['dogId'] as String?,
      missionId: data['mission_id'] as String? ?? data['missionId'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      events: (data['events'] as List<dynamic>?)
              ?.map((e) => VideoEvent.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      isFavorite: data['is_favorite'] as bool? ??
          data['isFavorite'] as bool? ?? false,
      isShared: data['is_shared'] as bool? ??
          data['isShared'] as bool? ?? false,
    );
  }

  /// Format duration as MM:SS
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// An event that occurred during a video clip
@freezed
class VideoEvent with _$VideoEvent {
  const VideoEvent._();

  const factory VideoEvent({
    required Duration timestamp,
    required String type,
    String? label,
  }) = _VideoEvent;

  factory VideoEvent.fromJson(Map<String, dynamic> json) =>
      _$VideoEventFromJson(json);

  /// Create from API response
  factory VideoEvent.fromApiResponse(Map<String, dynamic> data) {
    return VideoEvent(
      timestamp: Duration(
        milliseconds: data['timestamp_ms'] as int? ??
            (data['timestamp_seconds'] as int? ?? 0) * 1000,
      ),
      type: data['type'] as String? ?? 'unknown',
      label: data['label'] as String?,
    );
  }

  /// Format timestamp as M:SS
  String get formattedTimestamp {
    final minutes = timestamp.inMinutes;
    final seconds = timestamp.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
