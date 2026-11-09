import 'package:flutter/material.dart';

import '../../core/utils/time_utils.dart';
import '../../theme/wimz_colors.dart';

/// Types of guardian events from the robot
enum GuardianEventType {
  dogDetected('dog_detected', 'Dog detected', Icons.pets),
  dogLeft('dog_left', 'Dog left frame', Icons.directions_walk),
  barkingDetected('barking', 'Barking detected', Icons.volume_up),
  treatDispensed('treat_dispensed', 'Treat dispensed', Icons.card_giftcard),
  behaviorChange('behavior_change', 'Behavior change', Icons.psychology),
  motionDetected('motion_detected', 'Motion detected', Icons.motion_photos_on),
  quietReward('quiet_reward', 'Quiet reward', Icons.star),
  alertTriggered('alert_triggered', 'Alert triggered', Icons.warning),
  unknown('unknown', 'Event', Icons.info);

  final String value;
  final String label;
  final IconData icon;

  const GuardianEventType(this.value, this.label, this.icon);

  /// Brand colour for this event type. Alerts and barking use the error
  /// slot; treats and quiet rewards are ink; a detected dog is a live
  /// signal; everything else is ink-muted. Callers always draw [icon] and
  /// the label beside it, so colour never carries the meaning alone.
  Color colorOf(BuildContext context) {
    final w = context.wimz;
    switch (this) {
      case GuardianEventType.barkingDetected:
      case GuardianEventType.alertTriggered:
        return Theme.of(context).colorScheme.error;
      case GuardianEventType.treatDispensed:
      case GuardianEventType.quietReward:
        return w.ink;
      case GuardianEventType.dogDetected:
        return w.signal;
      case GuardianEventType.dogLeft:
      case GuardianEventType.behaviorChange:
      case GuardianEventType.motionDetected:
      case GuardianEventType.unknown:
        return w.inkMuted;
    }
  }

  static GuardianEventType fromString(String value) {
    return GuardianEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GuardianEventType.unknown,
    );
  }
}

/// A single guardian event from the robot
class GuardianEvent {
  final String id;
  final GuardianEventType type;
  final DateTime timestamp;
  final String? details;
  final Map<String, dynamic>? metadata;

  const GuardianEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.details,
    this.metadata,
  });

  factory GuardianEvent.fromJson(Map<String, dynamic> json) {
    return GuardianEvent(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: GuardianEventType.fromString(json['event_type'] ?? json['type'] ?? 'unknown'),
      timestamp: parseServerTimestamp(json['timestamp']?.toString()),
      details: json['details']?.toString() ?? json['message']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Format timestamp for display (e.g., "10:30 AM")
  String get formattedTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Get display text combining type label and details
  String get displayText {
    if (details != null && details!.isNotEmpty) {
      return '${type.label} - $details';
    }
    return type.label;
  }
}
