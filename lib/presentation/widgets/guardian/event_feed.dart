import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/guardian_event.dart';
import '../../../domain/providers/guardian_events_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../silent_guardian/sg_summary_card.dart';

/// Widget displaying a scrollable feed of guardian events
class EventFeed extends ConsumerStatefulWidget {
  const EventFeed({super.key});

  @override
  ConsumerState<EventFeed> createState() => _EventFeedState();
}

class _EventFeedState extends ConsumerState<EventFeed> {
  @override
  void initState() {
    super.initState();
    // Start listening when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guardianEventsProvider.notifier).startListening();
      ref.read(guardianEventsProvider.notifier).markAllRead();
    });
  }

  @override
  void dispose() {
    ref.read(guardianEventsProvider.notifier).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsState = ref.watch(guardianEventsProvider);
    final events = eventsState.sortedEvents;

    if (events.isEmpty) {
      return Column(
        children: [
          // Robot 137a5e8: live session summary (level-4 auto or manual pull)
          const SgSummaryCard(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 64,
                    color: context.wimz.inkMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.eventFeedSgActive,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.wimz.ink,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.eventFeedWatching,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.wimz.inkMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Robot 137a5e8: live session summary (level-4 auto or manual pull)
        const SgSummaryCard(),
        // Header with event count and clear button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.eventFeedRecentEvents(events.length),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.wimz.ink,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(guardianEventsProvider.notifier).clearEvents();
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: Text(context.l10n.eventFeedClear),
                style: TextButton.styleFrom(
                  foregroundColor: context.wimz.inkMuted,
                ),
              ),
            ],
          ),
        ),

        // Event list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return EventCard(event: events[index]);
            },
          ),
        ),
      ],
    );
  }
}

/// A single event card in the feed
class EventCard extends StatelessWidget {
  final GuardianEvent event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    // Type colour from the model's brand map; the icon + label beside it
    // always carry the meaning.
    final color = event.type.colorOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      // Flat brand card: raised fill, 1px line edge, no tint, no shadow.
      decoration: WimzTheme.cardDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: w.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            event.type.icon,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          event.type.localizedLabel(context.l10n),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        subtitle: event.details != null
            ? Text(
                event.details!,
                style: TextStyle(
                  color: w.inkMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          event.localizedTime(context.l10n),
          style: TextStyle(
            color: w.inkMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Compact event card for smaller displays
class CompactEventCard extends StatelessWidget {
  final GuardianEvent event;

  const CompactEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: WimzTheme.cardDecoration(context, radius: 8),
      child: Row(
        children: [
          Icon(event.type.icon, color: event.type.colorOf(context), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.localizedDisplayText(context.l10n),
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            event.localizedTime(context.l10n),
            style: TextStyle(
              fontSize: 11,
              color: w.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
