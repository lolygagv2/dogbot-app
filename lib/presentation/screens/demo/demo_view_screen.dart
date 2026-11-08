import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ai_connection.dart';
import '../../../domain/providers/agent_transcript_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/sg_summary_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo/demo_controls_panel.dart';
import '../../widgets/summary/today_card.dart';

/// Demo view for screen mirroring: Today card · Silent Guardian summary ·
/// live agent transcript. Three fixed panes (side by side in landscape,
/// stacked in portrait); only the transcript scrolls, and it auto-follows.
/// Admin accounts also get a replayer control strip along the bottom
/// (B176, relay `/admin/replay`).
class DemoViewScreen extends ConsumerStatefulWidget {
  const DemoViewScreen({super.key});

  @override
  ConsumerState<DemoViewScreen> createState() => _DemoViewScreenState();
}

class _DemoViewScreenState extends ConsumerState<DemoViewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sg = ref.read(sgSummaryProvider);
      if (sg.summary == null && !sg.pulling) {
        ref.read(sgSummaryProvider.notifier).pull();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dog = ref.watch(selectedDogProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.pets, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'WIM-Z',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppTheme.primary,
                      shadows: AppTheme.glowShadow(AppTheme.primary, blur: 12)
                          .map((s) => Shadow(color: s.color, blurRadius: s.blurRadius))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (dog != null)
                    Text(dog.name,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > c.maxHeight;
                    final panes = [
                      _Pane(
                        title: l.todayCardTitle,
                        icon: Icons.today,
                        color: AppTheme.primary,
                        child: dog == null
                            ? _Empty(l.demoNoDog)
                            : TodayCard(
                                dogId: dog.id, dogName: dog.name, compact: true),
                      ),
                      _Pane(
                        title: l.demoPanelGuardian,
                        icon: Icons.shield_outlined,
                        color: Colors.purple,
                        child: const _SgPanel(),
                      ),
                      _Pane(
                        title: l.demoPanelTranscript,
                        icon: Icons.forum_outlined,
                        color: AppTheme.secondary,
                        child: const _TranscriptPanel(),
                      ),
                    ];
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: panes[0]),
                          const SizedBox(width: 10),
                          Expanded(flex: 4, child: panes[1]),
                          const SizedBox(width: 10),
                          Expanded(flex: 5, child: panes[2]),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: panes[0]),
                        const SizedBox(height: 8),
                        Expanded(flex: 3, child: panes[1]),
                        const SizedBox(height: 8),
                        Expanded(flex: 4, child: panes[2]),
                      ],
                    );
                  },
                ),
              ),
              // Admin-only replayer controls (hidden for everyone else).
              const DemoControlsPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _Pane({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: ClipRect(child: child)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
      );
}

/// Compact Silent Guardian summary: headline, 4 stats, bark-type bar.
class _SgPanel extends ConsumerWidget {
  const _SgPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sgSummaryProvider);
    final s = state.summary;
    final l = context.l10n;
    if (s == null) {
      return _Empty(state.pulling
          ? l.loading
          : (state.error ?? l.demoSgIdle));
    }
    final types = s.barkTypePercentages.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.headline != null)
          Text(
            s.headline!,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (s.currentAction != null)
          Text(
            s.currentAction!,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Stat(l.sgStatBarks, '${s.totalBarks}'),
            _Stat(l.sgStatTreats, '${s.treatsDispensed}'),
            _Stat(l.sgStatInterventions, '${s.interventionsTriggered}'),
            _Stat(
              l.sgStatLevel,
              s.escalationLevel?.toString() ?? '–',
              color: (s.escalationLevel ?? 0) >= 4 ? AppTheme.error : null,
            ),
            _Trend(trend: s.trend),
          ],
        ),
        if (types.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final e in types)
                    Expanded(
                      flex: (e.value * 10).round().clamp(1, 1000),
                      child: Container(
                          color: AppTheme.barkTypeColors[e.key] ?? Colors.blueGrey),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final e in types.take(4))
                Text(
                  '${e.key} ${e.value.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.barkTypeColors[e.key] ?? Colors.blueGrey),
                ),
            ],
          ),
        ],
        if (s.panicActive) ...[
          const SizedBox(height: 6),
          Text(l.sgPanicActive,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error)),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color ?? AppTheme.textPrimary)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: AppTheme.textTertiary),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _Trend extends StatelessWidget {
  final String? trend;
  const _Trend({required this.trend});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trend) {
      'improving' => (Icons.trending_down, Colors.green),
      'worsening' => (Icons.trending_up, AppTheme.error),
      _ => (Icons.trending_flat, AppTheme.textTertiary),
    };
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          Text(context.l10n.sgStatTrend,
              style: const TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }
}

/// Agent transcript — newest at the bottom, auto-scrolls as lines arrive.
class _TranscriptPanel extends ConsumerStatefulWidget {
  const _TranscriptPanel();
  @override
  ConsumerState<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends ConsumerState<_TranscriptPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(agentTranscriptProvider);
    ref.listen(agentTranscriptProvider, (_, __) => _follow());
    final l = context.l10n;
    if (lines.isEmpty) return _Empty(l.demoTranscriptEmpty);
    final locale = Localizations.localeOf(context).toString();
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isUser = line.role == 'user';
        final color = isUser
            ? AppTheme.primary
            : switch (line.provider) {
                AiProvider.chatgpt => const Color(0xFF10A37F),
                AiProvider.claude => const Color(0xFFD97757),
                AiProvider.grok => const Color(0xFFE0E0E0),
                AiProvider.perplexity => const Color(0xFF20B8CD),
                null => AppTheme.secondary,
              };
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(line.speaker,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(width: 6),
                  Text(DateFormat.Hm(locale).format(line.ts.toLocal()),
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textTertiary)),
                ],
              ),
              Text(line.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: line.role == 'tool'
                        ? AppTheme.textTertiary
                        : AppTheme.textPrimary,
                    fontStyle: line.role == 'tool'
                        ? FontStyle.italic
                        : FontStyle.normal,
                  )),
            ],
          ),
        );
      },
    );
  }
}
