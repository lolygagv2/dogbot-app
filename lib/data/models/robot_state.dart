/// ROBOT-STATE v2 — the relay-owned state record of one robot (contract
/// section 1). Arrives as the WS `robot_state` frame (E2), from
/// `GET /api/devices/{device_id}/state` (H1) and as the answer to
/// `POST /api/devices/{device_id}/selected_dog` (H2).
///
/// Wire names are fixed by the contract; do not rename or alias them.
class RobotState {
  final String? deviceId;
  final bool robotOnline;

  /// Exactly one of: idle | silent_guardian | coach | mission | manual.
  /// Sleep is NOT a mode — see [asleep].
  final String mode;
  final bool asleep;

  /// The dog chosen in the app (one stored value, last write wins).
  final String? selectedDogId;

  /// True only after the robot confirmed the current [selectedDogId].
  final bool selectedDogApplied;
  final String? sessionDogId;
  final int stateVersion;
  final DateTime? updatedAt;
  final String? source;
  final String? reason;

  const RobotState({
    this.deviceId,
    this.robotOnline = false,
    this.mode = 'idle',
    this.asleep = false,
    this.selectedDogId,
    this.selectedDogApplied = false,
    this.sessionDogId,
    this.stateVersion = 0,
    this.updatedAt,
    this.source,
    this.reason,
  });

  /// Lenient parse (relay JSON is never strictly cast). Returns null when
  /// the object carries no usable `mode` — it is not a state record then.
  static RobotState? tryParse(Map<dynamic, dynamic> j) {
    final mode = j['mode']?.toString();
    if (mode == null || mode.isEmpty) return null;
    String? str(String k) {
      final v = j[k];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    final ver = j['state_version'];
    return RobotState(
      deviceId: str('device_id'),
      robotOnline: j['robot_online'] == true,
      mode: mode,
      asleep: j['asleep'] == true,
      selectedDogId: str('selected_dog_id'),
      selectedDogApplied: j['selected_dog_applied'] == true,
      sessionDogId: str('session_dog_id'),
      stateVersion: ver is num ? ver.toInt() : int.tryParse('$ver') ?? 0,
      updatedAt: DateTime.tryParse(str('updated_at') ?? ''),
      source: str('source'),
      reason: str('reason'),
    );
  }

  @override
  String toString() =>
      'v$stateVersion mode=$mode asleep=$asleep online=$robotOnline '
      'sel=$selectedDogId applied=$selectedDogApplied session=$sessionDogId '
      'source=$source reason=$reason';
}
