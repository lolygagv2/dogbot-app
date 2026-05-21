import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quality tier the robot is currently streaming at, as published over the
/// WebRTC data channel in `video_quality_state` messages.
enum VideoTier {
  low,
  medium,
  high;

  /// Parse the robot's `tier` string; null/unknown → null.
  static VideoTier? fromString(String? s) {
    switch (s) {
      case 'low':
        return VideoTier.low;
      case 'medium':
        return VideoTier.medium;
      case 'high':
        return VideoTier.high;
      default:
        return null;
    }
  }

  /// User-facing label, e.g. "HD 720p".
  String get label {
    switch (this) {
      case VideoTier.low:
        return 'SD 480p';
      case VideoTier.medium:
        return '540p';
      case VideoTier.high:
        return 'HD 720p';
    }
  }
}

/// The user's video-quality override selection. `auto` lets the robot's
/// adaptive controller pick the tier; the others pin it. Persisted in
/// AppSettings; sent to the robot as the `set_video_quality` command.
enum VideoQualityMode {
  auto,
  low,
  medium,
  high;

  /// Parse a persisted name; unknown/null → [auto].
  static VideoQualityMode fromName(String? name) {
    return VideoQualityMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => VideoQualityMode.auto,
    );
  }

  String get label {
    switch (this) {
      case VideoQualityMode.auto:
        return 'Auto';
      case VideoQualityMode.low:
        return 'Low';
      case VideoQualityMode.medium:
        return 'Medium';
      case VideoQualityMode.high:
        return 'High';
    }
  }
}

/// Snapshot of the robot's video-quality state, parsed from a
/// `video_quality_state` data-channel message. Immutable.
class VideoQualityState {
  final VideoTier tier;
  final String resolution; // e.g. "1280x720"
  final int bitrateKbps;
  final double lossPct; // 0-100
  final int rttMs;
  final int bars; // 0-4 signal bars
  final bool manualOverride; // true = robot tier pinned, adaptation disabled
  final DateTime receivedAt;

  const VideoQualityState({
    required this.tier,
    required this.resolution,
    required this.bitrateKbps,
    required this.lossPct,
    required this.rttMs,
    required this.bars,
    required this.manualOverride,
    required this.receivedAt,
  });

  /// Parse from a decoded `video_quality_state` JSON map. Returns null if the
  /// message has no recognisable tier (treated as malformed).
  static VideoQualityState? fromJson(Map<String, dynamic> json) {
    final tier = VideoTier.fromString(json['tier'] as String?);
    if (tier == null) return null;
    return VideoQualityState(
      tier: tier,
      resolution: json['resolution'] as String? ?? '',
      bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 0,
      lossPct: (json['loss_pct'] as num?)?.toDouble() ?? 0.0,
      rttMs: (json['rtt_ms'] as num?)?.toInt() ?? 0,
      bars: ((json['bars'] as num?)?.toInt() ?? 0).clamp(0, 4),
      manualOverride: json['manual_override'] as bool? ?? false,
      receivedAt: DateTime.now(),
    );
  }
}

/// Holds the latest [VideoQualityState] the robot published over the WebRTC
/// data channel. `null` = no state received yet, or the connection was torn
/// down. Written only by [WebRTCNotifier]'s data-channel handler — never
/// from the UI.
final videoQualityStateProvider =
    StateNotifierProvider<VideoQualityNotifier, VideoQualityState?>((ref) {
  return VideoQualityNotifier();
});

class VideoQualityNotifier extends StateNotifier<VideoQualityState?> {
  VideoQualityNotifier() : super(null);

  /// Apply a `video_quality_state` message from the robot's data channel.
  void updateFromRobot(Map<String, dynamic> json) {
    final parsed = VideoQualityState.fromJson(json);
    if (parsed == null) {
      print('VideoQuality: ignoring malformed video_quality_state: $json');
      return;
    }
    state = parsed;
  }

  /// Clear the state — called on WebRTC teardown so the UI shows
  /// "not connected" rather than stale data.
  void clear() {
    state = null;
  }
}
