import 'package:flutter/material.dart';

/// Types of guardian events from the robot
enum GuardianEventType {
  dogDetected('dog_detected', 'Dog detected', Icons.pets, Colors.blue),
  dogLeft('dog_left', 'Dog left frame', Icons.directions_walk, Colors.grey),
  barkingDetected('barking', 'Barking detected', Icons.volume_up, Colors.red),
  treatDispensed('treat_dispensed', 'Treat dispensed', Icons.card_giftcard, Colors.green),
  behaviorChange('behavior_change', 'Behavior change', Icons.psychology, Colors.orange),
  motionDetected('motion_detected', 'Motion detected', Icons.motion_photos_on, Colors.purple),
  quietReward('quiet_reward', 'Quiet reward', Icons.star, Colors.amber),
  alertTriggered('alert_triggered', 'Alert triggered', Icons.warning, Colors.deepOrange),
  unknown('unknown', 'Event', Icons.info, Colors.grey);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const GuardianEventType(this.value, this.label, this.icon, this.color);

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
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
