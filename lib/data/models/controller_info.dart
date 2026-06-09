// Models for robot-hosted Xbox controller pairing.
//
// The robot owns the Bluetooth stack and is authoritative for all controller
// state. The app never uses phone Bluetooth — it is a remote control panel
// that asks the robot to scan/pair/trust/forget and renders the snapshot the
// robot pushes back over WebSocket. Plain classes (no codegen) to match the
// `WifiNetwork` / `NetworkStatusData` pattern in wifi_config_provider.dart.

/// A single Bluetooth game controller as the robot sees it.
class ControllerInfo {
  /// BlueZ device address, e.g. "DC:26:39:AA:BB:CC". Stable identity.
  final String address;
  final String name;

  /// Bonded with the robot (BlueZ "Paired").
  final bool paired;

  /// Persisted to the robot's auto-reconnect allowlist (BlueZ "Trusted").
  /// This is the user's sign-off that survives reboots and drops.
  final bool trusted;

  /// Currently connected and usable to drive the robot.
  final bool connected;

  /// 0–100 if the controller/robot reports it, else null.
  final int? battery;

  /// Signal strength from a scan result (dBm), else null. Discovery only.
  final int? rssi;

  const ControllerInfo({
    required this.address,
    required this.name,
    this.paired = false,
    this.trusted = false,
    this.connected = false,
    this.battery,
    this.rssi,
  });

  factory ControllerInfo.fromJson(Map<String, dynamic> json) {
    return ControllerInfo(
      address: (json['address'] ?? json['mac'] ?? '').toString(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Xbox Controller',
      paired: json['paired'] == true,
      trusted: json['trusted'] == true,
      connected: json['connected'] == true,
      battery: (json['battery'] as num?)?.toInt(),
      rssi: (json['rssi'] as num?)?.toInt(),
    );
  }

  /// A controller the robot remembers (bonded or trusted) vs. a fresh
  /// discovery result that has to be paired first.
  bool get isKnown => paired || trusted;

  ControllerInfo copyWith({
    bool? paired,
    bool? trusted,
    bool? connected,
    int? battery,
    int? rssi,
  }) {
    return ControllerInfo(
      address: address,
      name: name,
      paired: paired ?? this.paired,
      trusted: trusted ?? this.trusted,
      connected: connected ?? this.connected,
      battery: battery ?? this.battery,
      rssi: rssi ?? this.rssi,
    );
  }
}

/// Authoritative snapshot the robot pushes via the `controller_status` event.
class ControllerSnapshot {
  /// True while the robot has Bluetooth discovery running.
  final bool scanning;

  /// Every controller the robot knows about or has just discovered.
  final List<ControllerInfo> controllers;

  /// Address of the controller currently driving the robot (if any).
  final String? activeAddress;

  const ControllerSnapshot({
    this.scanning = false,
    this.controllers = const [],
    this.activeAddress,
  });

  factory ControllerSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['controllers'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((c) => ControllerInfo.fromJson(c.cast<String, dynamic>()))
            .where((c) => c.address.isNotEmpty)
            .toList()
        : <ControllerInfo>[];
    return ControllerSnapshot(
      scanning: json['scanning'] == true,
      controllers: list,
      activeAddress: json['active_address'] as String?,
    );
  }

  /// Known controllers (bonded/trusted) — shown in the "Saved" list.
  List<ControllerInfo> get known =>
      controllers.where((c) => c.isKnown).toList();

  /// Fresh discovery results not yet paired — shown in the "Found" list.
  List<ControllerInfo> get discovered =>
      controllers.where((c) => !c.isKnown).toList();

  ControllerInfo? get activeController {
    for (final c in controllers) {
      if (c.connected) return c;
    }
    return null;
  }
}
