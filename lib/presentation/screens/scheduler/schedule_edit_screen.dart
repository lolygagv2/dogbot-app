import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/schedule.dart';
import '../../../data/models/dog_profile.dart';
import '../../../data/models/mission.dart';
import '../../../domain/providers/scheduler_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../theme/app_theme.dart';

class ScheduleEditScreen extends ConsumerStatefulWidget {
  final String? scheduleId;

  const ScheduleEditScreen({super.key, this.scheduleId});

  @override
  ConsumerState<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends ConsumerState<ScheduleEditScreen> {
  String? _selectedDogId;
  String? _selectedMissionId;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  ScheduleType _selectedType = ScheduleType.daily;
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5}; // Mon-Fri default
  bool _isLoading = false;
  bool _isEditing = false;
  MissionSchedule? _existingSchedule;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.scheduleId != null;
    if (_isEditing) {
      _loadExistingSchedule();
    }
  }

  void _loadExistingSchedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schedule = ref.read(scheduleByIdProvider(widget.scheduleId!));
      if (schedule != null) {
        setState(() {
          _existingSchedule = schedule;
          _selectedDogId = schedule.dogId;
          _selectedMissionId = schedule.missionId;
          _selectedTime = TimeOfDay(hour: schedule.hour, minute: schedule.minute);
          _selectedType = schedule.type;
          _selectedWeekdays.clear();
          _selectedWeekdays.addAll(schedule.weekdays);
        });
      }
    });
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.surface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedDogId == null || _selectedMissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a dog and mission')),
      );
      return;
    }

    if (_selectedType == ScheduleType.weekly && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success;
    if (_isEditing && _existingSchedule != null) {
      final updated = _existingSchedule!.copyWith(
        missionId: _selectedMissionId!,
        dogId: _selectedDogId!,
        type: _selectedType,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        weekdays: _selectedWeekdays.toList()..sort(),
      );
      success = await ref.read(schedulerProvider.notifier).updateSchedule(updated);
    } else {
      success = await ref.read(schedulerProvider.notifier).createSchedule(
            missionId: _selectedMissionId!,
            dogId: _selectedDogId!,
            type: _selectedType,
            hour: _selectedTime.hour,
            minute: _selectedTime.minute,
            weekdays: _selectedWeekdays.toList()..sort(),
          );
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Schedule updated' : 'Schedule created'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        // Build 34: Show error feedback when save fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Failed to update schedule' : 'Failed to create schedule'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!_isEditing || widget.scheduleId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await ref
          .read(schedulerProvider.notifier)
          .deleteSchedule(widget.scheduleId!);
      if (success && mounted) {
        context.pop();
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dogs = ref.watch(dogProfilesProvider);
    final missions = ref.watch(missionsProvider).missions;

    // Set default selections if not set
    if (_selectedDogId == null && dogs.isNotEmpty && !_isEditing) {
      _selectedDogId = dogs.first.id;
    }
    if (_selectedMissionId == null && missions.isNotEmpty && !_isEditing) {
      _selectedMissionId = missions.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Schedule' : 'New Schedule'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dog selection
          _SectionTitle('Dog'),
          _DropdownCard<String>(
            value: _selectedDogId,
            items: dogs.map((d) => DropdownMenuItem(
              value: d.id,
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 20),
                  const SizedBox(width: 8),
                  Text(d.name),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedDogId = v),
            hint: 'Select a dog',
          ),

          const SizedBox(height: 24),

          // Mission selection
          _SectionTitle('Training Mission'),
          _DropdownCard<String>(
            value: _selectedMissionId,
            items: missions.map((m) => DropdownMenuItem(
              value: m.id,
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 20),
                  const SizedBox(width: 8),
                  Text(m.name),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedMissionId = v),
            hint: 'Select a mission',
          ),

          const SizedBox(height: 24),

          // Time selection
          _SectionTitle('Time'),
          _TimePickerCard(
            time: _selectedTime,
            onTap: _selectTime,
          ),

          const SizedBox(height: 24),

          // Repeat type
          _SectionTitle('Repeat'),
          _RepeatTypeSelector(
            selectedType: _selectedType,
            onChanged: (type) => setState(() => _selectedType = type),
          ),

          // Weekday selector (for weekly)
          if (_selectedType == ScheduleType.weekly) ...[
            const SizedBox(height: 16),
            _WeekdaySelector(
              selectedDays: _selectedWeekdays,
              onToggle: _toggleWeekday,
            ),
          ],

          // Delete button (for editing)
          if (_isEditing) ...[
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Icons.delete, color: AppTheme.error),
              label: const Text('Delete Schedule'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const _DropdownCard({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(hint, style: TextStyle(color: AppTheme.textTertiary)),
          isExpanded: true,
          dropdownColor: AppTheme.surfaceLight,
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              '$hour:$minute $period',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _RepeatTypeSelector extends StatelessWidget {
  final ScheduleType selectedType;
  final ValueChanged<ScheduleType> onChanged;

  const _RepeatTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ScheduleType.values.map((type) {
        final isSelected = type == selectedType;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: type == ScheduleType.once ? 0 : 4,
              right: type == ScheduleType.weekly ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => onChanged(type),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withOpacity(0.2)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.glassBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _iconForType(type),
                      color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labelForType(type),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForType(ScheduleType type) {
    switch (type) {
      case ScheduleType.once:
        return Icons.looks_one;
      case ScheduleType.daily:
        return Icons.repeat;
      case ScheduleType.weekly:
        return Icons.calendar_view_week;
    }
  }

  String _labelForType(ScheduleType type) {
    switch (type) {
      case ScheduleType.once:
        return 'Once';
      case ScheduleType.daily:
        return 'Daily';
      case ScheduleType.weekly:
        return 'Weekly';
    }
  }
}

class _WeekdaySelector extends StatelessWidget {
  final Set<int> selectedDays;
  final ValueChanged<int> onToggle;

  const _WeekdaySelector({
    required this.selectedDays,
    required this.onToggle,
  });

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final isSelected = selectedDays.contains(index);
        return InkWell(
          onTap: () => onToggle(index),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.glassBorder,
              ),
            ),
            child: Center(
              child: Text(
                _dayLabels[index],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppTheme.background
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
