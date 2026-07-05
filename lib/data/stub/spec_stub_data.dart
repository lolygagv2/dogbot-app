import '../models/spec_records.dart';

/// ============================ STUB DATA ONLY ============================
/// Sample rows shaped EXACTLY like `.claude/WIMZ_Data_Architecture_Spec.md`
/// tables (event §4/§5, session_report v0.2, media_asset §4). Every
/// event_type and payload shape below is copied from the spec's §5
/// taxonomy table — nothing invented.
///
/// Build-125 rule: NO mock data outside explicit demo/preview contexts.
/// This file is imported ONLY by the UI-preview hub (Settings →
/// Diagnostics → UI Previews). Never feed these into live providers.
/// Delete call sites as each view is wired to real data (Chains SG / REC /
/// STORE Workstream C).
/// ========================================================================
class SpecStubData {
  SpecStubData._();

  static const _sessionId = '01981b2e-0000-7000-8000-3f6a1c9d2e01';
  static const _deviceId = '01977aa0-0000-7000-8000-9b2f4e6d1c02';
  static const _dogId = '01979c10-0000-7000-8000-5d8e2a7b4f03';

  /// One worked "sit" attempt + ambient events, mirroring spec §6's
  /// closed-loop example and §5 payload examples.
  static List<SpecEvent> events() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var seq = 0;
    SpecEvent e(
      int agoMs,
      String type,
      Map<String, dynamic> payload, {
      double? confidence,
      String? modelId,
      String labelSource = 'machine',
      String? mediaId,
      String? dogId = _dogId,
    }) =>
        SpecEvent(
          eventId: '0198stub-${seq.toString().padLeft(4, '0')}',
          sessionId: _sessionId,
          deviceId: _deviceId,
          dogId: dogId,
          ts: now - agoMs,
          seq: seq++,
          eventType: type,
          payload: payload,
          confidence: confidence,
          modelId: modelId,
          labelSource: labelSource,
          mediaId: mediaId,
        );

    return [
      e(9 * 60000, 'detection',
          {'bbox': [212, 148, 96, 132], 'class': 'dog', 'track_id': 7},
          confidence: 0.87, modelId: 'dogdetector_14', dogId: null),
      e(8 * 60000, 'dog_identified',
          {'method': 'qr', 'qr_code_id': 'wimz-qr-0007'},
          confidence: 0.99, modelId: 'dogdetector_14'),
      e(7 * 60000, 'cue_issued',
          {'trick': 'sit', 'cue_type': 'llm_audio', 'text': 'Rex, sit!'}),
      e(7 * 60000 - 1800, 'pose', {
        'pose': 'sit',
        'bbox': [220, 160, 90, 120],
        'keypoints': [],
      }, confidence: 0.91, modelId: 'dogpose_3', mediaId: stubMediaAsset.mediaId),
      e(7 * 60000 - 2200, 'treat_dispensed', {'slot': 12}),
      e(5 * 60000, 'pose_rejected', {'pose': 'down', 'reason': 'low_conf'},
          confidence: 0.38, modelId: 'dogpose_3'),
      e(4 * 60000, 'bark', {'db': 62, 'duration_ms': 900, 'class': 'bark'},
          confidence: 0.82, modelId: 'barkclassifier_2'),
      e(2 * 60000, 'pilot_action', {'action': 'drive', 'vec': [0.4, 0.0]},
          dogId: null),
      e(1 * 60000, 'error',
          {'code': 'motor_stall', 'detail': 'left track stall @ 2.1A'},
          dogId: null),
    ];
  }

  /// session_report per spec v0.2: relay-generated, one per session,
  /// stats_json holds the raw numbers (outcome_snapshot field names).
  static SessionReport sessionReport() => SessionReport(
        reportId: '0198stub-7000-8000-report-000000000001',
        sessionId: _sessionId,
        dogId: _dogId,
        generatedAt: DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        modelId: 'claude-haiku-4-5',
        inputHash:
            'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00',
        summaryText:
            'Rex had a focused 10-minute training session. He responded to '
            '4 of 5 "sit" cues, with an average response time of 1.8 '
            'seconds — his fastest week so far. One treat jammed briefly '
            'but dispensed on retry. A single sustained barking episode '
            'settled without escalation. Keep sessions at this length; '
            'consider introducing "down" next.',
        statsJson: const {
          'trick_label': 'sit',
          'attempts': 5,
          'successes': 4,
          'success_rate': 0.8,
          'avg_latency_ms': 1800,
          'treats_dispensed': 4,
          'bark_events': 1,
        },
      );

  /// media_asset per spec §4; rel_path follows the §3 media layout
  /// ( media/{dog_id}/{YYYY-MM-DD}/{session_id}/{event_id}.mp4 ).
  static const MediaAsset stubMediaAsset = MediaAsset(
    mediaId: '0198stub-7000-8000-media-000000000001',
    sessionId: _sessionId,
    dogId: _dogId,
    kind: 'video',
    relPath:
        'media/$_dogId/2026-07-05/$_sessionId/0198stub-0003.mp4',
    codec: 'h264',
    width: 1280,
    height: 720,
    durationMs: 14200,
    sizeBytes: 9437184,
    sha256:
        'ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12',
    retentionClass: 'standard',
  );
}
