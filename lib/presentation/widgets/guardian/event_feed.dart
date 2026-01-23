import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/guardian_event.dart';
import '../../../domain/providers/guardian_events_provider.dart';

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
  Widget build(BuildContext context) {
    final eventsState = ref.watch(guardianEventsProvider);
    final events = eventsState.sortedEvents;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility,
              size: 64,
              color: Colors.purple.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Silent Guardian Active',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watching for activity...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 24),
            // Debug: Add test event button
            OutlinedButton.icon(
              onPressed: () {
                ref.read(guardianEventsProvider.notifier).addTestEvent(
                      GuardianEventType.dogDetected,
                      'Test detection',
                    );
              },
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Add Test Event'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with event count and clear button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Events (${events.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(guardianEventsProvider.notifier).clearEvents();
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: event.type.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.type.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: event.type.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            event.type.icon,
            color: event.type.color,
            size: 22,
          ),
        ),
        title: Text(
          event.type.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: event.type.color,
          ),
        ),
        subtitle: event.details != null
            ? Text(
                event.details!,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          event.formattedTime,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: event.type.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(event.type.icon, color: event.type.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.displayText,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            event.formattedTime,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
