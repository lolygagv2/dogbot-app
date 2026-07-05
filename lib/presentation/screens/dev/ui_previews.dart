import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/models/spec_records.dart';
import '../../../data/stub/spec_stub_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video/video_saved_sheet.dart';

/// UI shells for the spec-driven views (Chains SG / REC / STORE Workstream
/// C), reviewable today against stub data and wired to real data later.
///
/// The stub data is passed ONLY here, at the preview call site — the view
/// widgets themselves ([EventListView], [SessionReportView],
/// [VideoSavedSheet]) have no stub dependency, so wiring them later is just
/// constructing them with real rows. Every view fed from this hub shows a
/// "SAMPLE DATA" banner (Build-125 rule: fake data must never be mistakable
/// for live data).
class UiPreviewHubScreen extends StatelessWidget {
  const UiPreviewHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Previews')),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppTheme.surfaceLight,
            child: Text(
              'Developer previews rendered from spec-shaped SAMPLE data '
              '(WIMZ_Data_Architecture_Spec.md). Nothing here is live.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Event list'),
            subtitle: const Text('spec `event` rows (§4/§5 taxonomy)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventListView(
                  events: SpecStubData.events(),
                  sampleData: true,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Session report'),
            subtitle: const Text('spec `session_report` (v0.2, relay LLM)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionReportView(
                  report: SpecStubData.sessionReport(),
                  sampleData: true,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.video_file_outlined),
            title: const Text('Video saved confirmation'),
            subtitle: const Text('spec `media_asset` (§4) — Chain REC'),
            onTap: () => VideoSavedSheet.show(
              context,
              SpecStubData.stubMediaAsset,
              sampleData: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow strip shown on any view rendered from stub rows.
class SampleDataBanner extends StatelessWidget {
  const SampleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade800,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Text(
        'SAMPLE DATA — not live',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// List of spec `event` rows. Chain SG display surface: to wire, construct
/// with rows fetched from the relay/robot (persisted events) instead of
/// stubs.
class EventListView extends StatelessWidget {
  final List<SpecEvent> events;
  final bool sampleData;

  const EventListView({
    super.key,
    required this.events,
    this.sampleData = false,
  });

  static const _typeIcons = <String, IconData>{
    'detection': Icons.center_focus_weak,
    'pose': Icons.pets,
    'pose_rejected': Icons.pets_outlined,
    'bark': Icons.graphic_eq,
    'dog_identified': Icons.qr_code_2,
    'cue_issued': Icons.record_voice_over,
    'treat_dispensed': Icons.cookie,
    'pilot_action': Icons.sports_esports,
    'error': Icons.error_outline,
  };

  String _payloadSummary(SpecEvent e) {
    switch (e.eventType) {
      case 'detection':
        return 'class=${e.payload['class']} track=${e.payload['track_id']}';
      case 'pose':
      case 'pose_rejected':
        final reason = e.payload['reason'];
        return 'pose=${e.payload['pose']}${reason != null ? ' ($reason)' : ''}';
      case 'bark':
        return '${e.payload['db']} dB, ${e.payload['duration_ms']} ms';
      case 'dog_identified':
        return 'via ${e.payload['method']}';
      case 'cue_issued':
        return '"${e.payload['text'] ?? e.payload['trick']}"';
      case 'treat_dispensed':
        return 'slot ${e.payload['slot']}';
      case 'pilot_action':
        return '${e.payload['action']}';
      case 'error':
        return '${e.payload['code']}';
      default:
        return jsonEncode(e.payload);
    }
  }

  String _time(SpecEvent e) {
    final t = e.time.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => b.ts.compareTo(a.ts));
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Column(
        children: [
          if (sampleData) const SampleDataBanner(),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No events'))
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = sorted[i];
                      final isError = e.eventType == 'error';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _typeIcons[e.eventType] ?? Icons.circle_outlined,
                          color:
                              isError ? AppTheme.error : AppTheme.primary,
                          size: 22,
                        ),
                        title: Text(
                          e.eventType,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${_time(e)} · ${_payloadSummary(e)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (e.confidence != null)
                              Text(
                                '${(e.confidence! * 100).round()}%',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            // Label provenance (spec §1.3): who produced it.
                            Text(
                              e.labelSource == 'machine'
                                  ? (e.modelId ?? 'machine')
                                  : e.labelSource,
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One relay-generated session report (spec v0.2 `session_report`).
/// STORE Workstream C display surface: to wire, fetch the report row by
/// session from the relay and construct this with it.
class SessionReportView extends StatelessWidget {
  final SessionReport report;
  final bool sampleData;

  const SessionReportView({
    super.key,
    required this.report,
    this.sampleData = false,
  });

  @override
  Widget build(BuildContext context) {
    final stats = report.statsJson;
    return Scaffold(
      appBar: AppBar(title: const Text('Session Report')),
      body: Column(
        children: [
          if (sampleData) const SampleDataBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Text(
                    report.summaryText,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                if (stats.isNotEmpty) ...[
                  const Text(
                    'STATS',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in stats.entries)
                        Chip(
                          label: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceLight,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Provenance footer (spec: model_id is the literal API
                // string; input_hash is the idempotency key).
                Text(
                  'Generated ${report.generatedTime.toLocal()} · '
                  '${report.modelId} · '
                  'input ${report.inputHash.length >= 8 ? report.inputHash.substring(0, 8) : report.inputHash}…',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
