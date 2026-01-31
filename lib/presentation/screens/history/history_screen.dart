import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/mission.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/history_provider.dart';
import '../../theme/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final String? dogId;

  const HistoryScreen({super.key, this.dogId});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load history when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.dogId != null) {
        ref.read(historyProvider.notifier).setDogId(widget.dogId);
      } else {
        ref.read(historyProvider.notifier).loadHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final dogs = ref.watch(dogProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _FilterBar(
            filter: historyState.filter,
            dogs: dogs,
            onDaysChanged: (days) =>
                ref.read(historyProvider.notifier).setDays(days),
            onDogChanged: (dogId) =>
                ref.read(historyProvider.notifier).setDogId(dogId),
          ),

          // Stats summary
          if (historyState.stats != null || historyState.entries.isNotEmpty)
            _StatsSummary(
              stats: historyState.stats,
              entries: historyState.entries,
            ),

          // Content
          Expanded(
            child: historyState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : historyState.error != null
                    ? _ErrorView(
                        message: historyState.error!,
                        onRetry: () => ref.read(historyProvider.notifier).refresh(),
                      )
                    : historyState.entries.isEmpty
                        ? const _EmptyView()
                        : _HistoryList(
                            entriesByDate: historyState.entriesByDate,
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final HistoryFilter filter;
  final List dogs;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String?> onDogChanged;

  const _FilterBar({
    required this.filter,
    required this.dogs,
    required this.onDaysChanged,
    required this.onDogChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.surface,
      child: Row(
        children: [
          // Days filter
          Expanded(
            child: DropdownButtonFormField<int>(
              value: filter.days,
              decoration: const InputDecoration(
                labelText: 'Time Range',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Today')),
                DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem(value: 14, child: Text('Last 2 weeks')),
                DropdownMenuItem(value: 30, child: Text('Last month')),
              ],
              onChanged: (value) {
                if (value != null) onDaysChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),

          // Dog filter
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: filter.dogId,
              decoration: const InputDecoration(
                labelText: 'Dog',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Dogs')),
                ...dogs.map((dog) => DropdownMenuItem(
                      value: dog.id,
                      child: Text(dog.name),
                    )),
              ],
              onChanged: onDogChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSummary extends StatelessWidget {
  final MissionStats? stats;
  final List<MissionHistoryEntry> entries;

  const _StatsSummary({
    this.stats,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final totalMissions = stats?.totalMissions ?? entries.length;
    final completedMissions = stats?.completedMissions ??
        entries.where((e) => e.wasCompleted).length;
    final totalTreats = stats?.totalTreats ??
        entries.fold<int>(0, (sum, e) => sum + e.treatsGiven);
    final successRate = stats?.successRate ??
        (entries.isEmpty
            ? 0.0
            : entries.where((e) => e.wasCompleted).length / entries.length);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.flag,
            label: 'Sessions',
            value: '$totalMissions',
          ),
          _StatItem(
            icon: Icons.check_circle,
            label: 'Completed',
            value: '$completedMissions',
            color: Colors.green,
          ),
          _StatItem(
            icon: Icons.cookie,
            label: 'Treats',
            value: '$totalTreats',
            color: Colors.amber,
          ),
          _StatItem(
            icon: Icons.trending_up,
            label: 'Success',
            value: '${(successRate * 100).toInt()}%',
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppTheme.textSecondary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final Map<DateTime, List<MissionHistoryEntry>> entriesByDate;

  const _HistoryList({required this.entriesByDate});

  @override
  Widget build(BuildContext context) {
    final sortedDates = entriesByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final entries = entriesByDate[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            // Entries for this date
            ...entries.map((entry) => _HistoryEntryCard(entry: entry)),
            if (index < sortedDates.length - 1) const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final MissionHistoryEntry entry;

  const _HistoryEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final durationStr = entry.completedAt != null
        ? _formatDuration(entry.completedAt!.difference(entry.startedAt))
        : 'In progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.wasCompleted
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.wasCompleted ? Icons.check_circle : Icons.cancel,
                color: entry.wasCompleted ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.missionName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        timeFormat.format(entry.startedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.timer, size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.cookie, size: 14, color: Colors.amber.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.treatsGiven}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade600,
                      ),
                    ),
                  ],
                ),
                if (entry.totalStages > 0)
                  Text(
                    '${entry.stagesCompleted}/${entry.totalStages} stages',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No training history',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some training sessions to see your progress',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
