import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ai_connection.dart';
import '../../../domain/providers/agent_transcript_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo/demo_controls_panel.dart';
import '../../widgets/demo/demo_guardian_panel.dart';
import '../../widgets/summary/today_card.dart';

/// Demo view for screen mirroring: Today card · Silent Guardian day summary ·
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dog = ref.watch(selectedDogProvider);
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  // The demo view's one gold mark: the brand paw.
                  Icon(Icons.pets, color: w.goldDeep, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'WIM-Z',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (dog != null)
                    Text(dog.name,
                        style: TextStyle(color: w.inkMuted)),
                  if (ref.watch(robotAsleepProvider)) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: w.surfaceSunken,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: w.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bedtime, size: 13, color: w.ink),
                          const SizedBox(width: 4),
                          Text(
                            l.modelRobotModeSleep,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: w.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: w.inkMuted),
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
                        color: cs.onSurface,
                        child: dog == null
                            ? _Empty(l.demoNoDog)
                            : TodayCard(
                                dogId: dog.id, dogName: dog.name, compact: true),
                      ),
                      _Pane(
                        title: l.demoPanelGuardian,
                        icon: Icons.shield_outlined,
                        color: cs.onSurface,
                        child: dog == null
                            ? _Empty(l.demoNoDog)
                            : DemoGuardianPanel(dogId: dog.id),
                      ),
                      _Pane(
                        title: l.demoPanelTranscript,
                        icon: Icons.forum_outlined,
                        color: cs.onSurface,
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
    final w = context.wimz;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: w.line),
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
            style: TextStyle(color: context.wimz.inkMuted, fontSize: 13)),
      );
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
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isUser = line.role == 'user';
        // Vendor colours are gone: the speaker name carries identity.
        final color = isUser
            ? cs.primary
            : switch (line.provider) {
                AiProvider.chatgpt ||
                AiProvider.claude ||
                AiProvider.grok ||
                AiProvider.perplexity ||
                null =>
                  w.ink,
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
                      style: TextStyle(
                          fontSize: 10, color: w.inkMuted)),
                ],
              ),
              Text(line.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: line.role == 'tool'
                        ? w.inkMuted
                        : w.ink,
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
