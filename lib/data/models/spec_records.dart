import 'dart:convert';

/// Typed mirrors of the shared data contract in
/// `.claude/WIMZ_Data_Architecture_Spec.md` (v0.2). Field names and types
/// come straight from the spec's SQL — do NOT add fields here; per the
/// spec's rule 0, additions go into the spec first, then get built.
///
/// Plain classes (no codegen) with lenient fromJson casts, matching the
/// controller_info.dart precedent: relay/robot JSON must never hard-crash
/// the app on a missing or oddly-typed field.
///
/// Timestamps are epoch milliseconds UTC (spec §4), kept as ints with
/// DateTime helpers so the raw wire value survives round-trips.

int? _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));
double? _asDouble(dynamic v) =>
    v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _asString(dynamic v) => v == null ? null : '$v';

Map<String, dynamic> _asJsonMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry('$k', val));
  if (v is String && v.isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {/* fall through */}
  }
  return const {};
}

/// Spec §4 `event` — the atomic log row. §5 defines the controlled
/// `event_type` vocabulary: detection, pose, pose_rejected, bark,
/// dog_identified, cue_issued, treat_dispensed, pilot_action, error.
class SpecEvent {
  final String eventId;
  final String sessionId;
  final String deviceId;
  final String? dogId; // NULL if unidentified
  final int ts; // epoch ms
  final int? seq; // monotonic within session
  final String eventType;
  final Map<String, dynamic> payload; // JSON, typed per event_type (§5)
  final double? confidence; // 0..1 for machine-produced events
  final String? modelId; // producer, if machine (label provenance)
  final String labelSource; // 'machine' | 'human' | 'auto_rule'
  final String? mediaId;

  const SpecEvent({
    required this.eventId,
    required this.sessionId,
    required this.deviceId,
    this.dogId,
    required this.ts,
    this.seq,
    required this.eventType,
    this.payload = const {},
    this.confidence,
    this.modelId,
    this.labelSource = 'machine',
    this.mediaId,
  });

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  factory SpecEvent.fromJson(Map<String, dynamic> json) => SpecEvent(
        eventId: _asString(json['event_id']) ?? '',
        sessionId: _asString(json['session_id']) ?? '',
        deviceId: _asString(json['device_id']) ?? '',
        dogId: _asString(json['dog_id']),
        ts: _asInt(json['ts']) ?? 0,
        seq: _asInt(json['seq']),
        eventType: _asString(json['event_type']) ?? 'error',
        payload: _asJsonMap(json['payload']),
        confidence: _asDouble(json['confidence']),
        modelId: _asString(json['model_id']),
        labelSource: _asString(json['label_source']) ?? 'machine',
        mediaId: _asString(json['media_id']),
      );
}

/// Spec v0.2 `session_report` — relay-generated natural-language summary of
/// one session. Relay-generated, app-read.
class SessionReport {
  final String reportId;
  final String sessionId;
  final String dogId;
  final int generatedAt; // epoch ms UTC
  final String modelId; // API model string, e.g. 'claude-haiku-4-5'
  final String inputHash; // sha256 of structured input (idempotency)
  final String summaryText; // the report shown in the app
  final Map<String, dynamic> statsJson; // raw numbers the summary used

  const SessionReport({
    required this.reportId,
    required this.sessionId,
    required this.dogId,
    required this.generatedAt,
    required this.modelId,
    required this.inputHash,
    required this.summaryText,
    this.statsJson = const {},
  });

  DateTime get generatedTime =>
      DateTime.fromMillisecondsSinceEpoch(generatedAt);

  factory SessionReport.fromJson(Map<String, dynamic> json) => SessionReport(
        reportId: _asString(json['report_id']) ?? '',
        sessionId: _asString(json['session_id']) ?? '',
        dogId: _asString(json['dog_id']) ?? '',
        generatedAt: _asInt(json['generated_at']) ?? 0,
        modelId: _asString(json['model_id']) ?? '',
        inputHash: _asString(json['input_hash']) ?? '',
        summaryText: _asString(json['summary_text']) ?? '',
        statsJson: _asJsonMap(json['stats_json']),
      );
}

/// Spec §4 `media_asset` — index row for a media file. The bytes live on the
/// robot's disk under /data; `rel_path` is relative to /data (§3) so the
/// tree is portable.
class MediaAsset {
  final String mediaId;
  final String? sessionId;
  final String? dogId;
  final String kind; // 'video' | 'image'
  final String relPath; // relative to /data
  final String? codec; // 'h264' | 'h265' | 'jpeg'
  final int? width;
  final int? height;
  final int? durationMs;
  final int? sizeBytes;
  final String? sha256; // integrity + dedupe on sync
  final int? startTs;
  final int? endTs;
  final String retentionClass; // 'permanent' | 'standard' | 'ephemeral'

  const MediaAsset({
    required this.mediaId,
    this.sessionId,
    this.dogId,
    required this.kind,
    required this.relPath,
    this.codec,
    this.width,
    this.height,
    this.durationMs,
    this.sizeBytes,
    this.sha256,
    this.startTs,
    this.endTs,
    this.retentionClass = 'standard',
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        mediaId: _asString(json['media_id']) ?? '',
        sessionId: _asString(json['session_id']),
        dogId: _asString(json['dog_id']),
        kind: _asString(json['kind']) ?? 'video',
        relPath: _asString(json['rel_path']) ?? '',
        codec: _asString(json['codec']),
        width: _asInt(json['width']),
        height: _asInt(json['height']),
        durationMs: _asInt(json['duration_ms']),
        sizeBytes: _asInt(json['size_bytes']),
        sha256: _asString(json['sha256']),
        startTs: _asInt(json['start_ts']),
        endTs: _asInt(json['end_ts']),
        retentionClass: _asString(json['retention_class']) ?? 'standard',
      );
}
