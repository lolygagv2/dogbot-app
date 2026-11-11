/// Models for the "Calming diffuser plug" feature (robot command
/// `smart_plug`). Plain classes with lenient parsing — the robot/relay JSON is
/// never trusted to carry exact types. [[defensive-json-no-silent-catch]]
library;

bool? _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == 'on' || s == '1') return true;
    if (s == 'false' || s == 'off' || s == '0') return false;
  }
  return null;
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

String? _asStr(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Absolute time from `auto_off_at`: epoch seconds / milliseconds or ISO8601.
DateTime? parseAutoOffAt(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    if (v <= 0) return null;
    final ms = v > 100000000000 ? v.toInt() : (v * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  final s = v.toString();
  final n = num.tryParse(s);
  if (n != null) return parseAutoOffAt(n);
  return DateTime.tryParse(s)?.toLocal();
}

/// Known error codes from a `smart_plug` command_result.
class SmartPlugError {
  static const plugUnreachable = 'plug_unreachable';
  static const plugNotFound = 'plug_not_found';
  static const invalidValue = 'invalid_value';
  static const missingDeviceId = 'missing_device_id';
  static const saveFailed = 'save_failed';

  /// App-side: nothing came back / could not send. Rendered as the generic
  /// "Couldn't reach the robot".
  static const noReply = 'no_reply';
}

/// One plug from a `scan` result.
class SmartPlugDevice {
  final String deviceId;
  final String alias;
  final String? model;
  final bool on;
  final bool selected;

  const SmartPlugDevice({
    required this.deviceId,
    required this.alias,
    this.model,
    this.on = false,
    this.selected = false,
  });

  static SmartPlugDevice? fromJson(Map<String, dynamic> j) {
    final id = _asStr(j['device_id'] ?? j['id']);
    if (id == null) return null;
    return SmartPlugDevice(
      deviceId: id,
      alias: _asStr(j['alias'] ?? j['name']) ?? id,
      model: _asStr(j['model']),
      on: _asBool(j['on']) ?? false,
      selected: _asBool(j['selected']) ?? false,
    );
  }
}

/// The status fields returned by `status`, `configure`, `on`, `off`.
class SmartPlugStatus {
  final bool configured;
  final String? deviceId;
  final String? alias;
  final String? model;
  final bool on;
  final bool reachable;

  /// "robot" when Silent Guardian turned it on (and will turn it off).
  final String? owner;

  /// When the robot will switch the plug off (robot-owned sessions only).
  /// Derived from `auto_off_in_s` at receipt, or `auto_off_at` on live events.
  final DateTime? autoOffAt;

  /// SG level that switches the plug on (1–4, default 2).
  final int triggerLevel;

  /// Minutes the robot keeps it on (default 120).
  final int autoOffMinutes;

  const SmartPlugStatus({
    this.configured = false,
    this.deviceId,
    this.alias,
    this.model,
    this.on = false,
    this.reachable = true,
    this.owner,
    this.autoOffAt,
    this.triggerLevel = 2,
    this.autoOffMinutes = 120,
  });

  bool get ownedByRobot => owner == 'robot';

  /// Parse a status payload. Fields missing from [j] keep the value from
  /// [prev] so a sparse reply (e.g. to `on`) never wipes what we know.
  factory SmartPlugStatus.fromJson(
    Map<String, dynamic> j, {
    SmartPlugStatus? prev,
  }) {
    final p = prev ?? const SmartPlugStatus();
    final on = _asBool(j['on']) ?? p.on;
    final owner =
        j.containsKey('owner') ? _asStr(j['owner']) : p.owner;

    DateTime? autoOffAt = p.autoOffAt;
    if (j.containsKey('auto_off_in_s')) {
      final s = _asInt(j['auto_off_in_s']);
      autoOffAt = (s != null && s > 0)
          ? DateTime.now().add(Duration(seconds: s))
          : null;
    } else if (j.containsKey('auto_off_at')) {
      autoOffAt = parseAutoOffAt(j['auto_off_at']);
    }
    if (!on || owner != 'robot') autoOffAt = null;

    return SmartPlugStatus(
      // A reply that carries status fields but omits `configured` is still a
      // configured plug (configure/on/off success "returns the status fields").
      configured: _asBool(j['configured']) ??
          (p.configured || j.containsKey('alias') || j.containsKey('on')),
      deviceId: _asStr(j['device_id']) ?? p.deviceId,
      alias: _asStr(j['alias']) ?? p.alias,
      model: _asStr(j['model']) ?? p.model,
      on: on,
      reachable: _asBool(j['reachable']) ?? true,
      owner: owner,
      autoOffAt: autoOffAt,
      triggerLevel: _asInt(j['trigger_level']) ?? p.triggerLevel,
      autoOffMinutes: _asInt(j['auto_off_minutes']) ?? p.autoOffMinutes,
    );
  }

  SmartPlugStatus copyWith({bool? on, bool? reachable}) => SmartPlugStatus(
        configured: configured,
        deviceId: deviceId,
        alias: alias,
        model: model,
        on: on ?? this.on,
        reachable: reachable ?? this.reachable,
        owner: owner,
        autoOffAt: autoOffAt,
        triggerLevel: triggerLevel,
        autoOffMinutes: autoOffMinutes,
      );
}
