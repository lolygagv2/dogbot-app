// Models for robot-hosted Xbox controller pairing.
//
// The robot owns the Bluetooth stack and is authoritative for all controller
// state. The app never uses phone Bluetooth — it is a remote control panel
// that asks the robot to scan/pair/trust/forget and renders the snapshot the
// robot pushes back over WebSocket. Plain classes (no codegen) to match the
// `WifiNetwork` / `NetworkStatusData` pattern in wifi_config_provider.dart.

/// Controller family, used only for display (glyph + pairing instructions).
/// The robot reports this; the app treats anything unknown as [generic] so a
/// new controller type can never break the screen.
enum ControllerKind { xbox, playstation, eightBitDo, generic }

/// A single Bluetooth game controller as the robot sees it.
class ControllerInfo {
  /// BlueZ device address, e.g. "DC:26:39:AA:BB:CC". Stable identity.
  final String address;
  final String name;

  /// Controller family for display only (see [ControllerKind]).
  final ControllerKind kind;

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
    this.kind = ControllerKind.generic,
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
          : 'Game Controller',
      kind: controllerKindFromString(json['kind'] as String?),
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
      kind: kind,
      paired: paired ?? this.paired,
      trusted: trusted ?? this.trusted,
      connected: connected ?? this.connected,
      battery: battery ?? this.battery,
      rssi: rssi ?? this.rssi,
    );
  }
}

/// Map the robot's `kind` string to a [ControllerKind]. Unknown/missing →
/// [ControllerKind.generic] so a brand we don't know about still works.
ControllerKind controllerKindFromString(String? raw) {
  switch (raw?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
    case 'xbox':
      return ControllerKind.xbox;
    case 'playstation':
    case 'ps':
    case 'ps4':
    case 'ps5':
    case 'dualshock':
    case 'dualsense':
      return ControllerKind.playstation;
    case '8bitdo':
    case 'eightbitdo':
      return ControllerKind.eightBitDo;
    default:
      return ControllerKind.generic;
  }
}

/// Human-facing family label, e.g. for the discovered-list subtitle.
String controllerKindLabel(ControllerKind kind) {
  switch (kind) {
    case ControllerKind.xbox:
      return 'Xbox';
    case ControllerKind.playstation:
      return 'PlayStation';
    case ControllerKind.eightBitDo:
      return '8BitDo';
    case ControllerKind.generic:
      return 'Controller';
  }
}

/// Per-family pairing-mode hint shown while scanning. Falls back to a generic
/// instruction for unknown controllers.
String controllerPairingHint(ControllerKind kind) {
  switch (kind) {
    case ControllerKind.xbox:
      return 'Hold the Xbox button, then hold the small Pair button on top '
          'until the light flashes quickly.';
    case ControllerKind.playstation:
      return 'Hold the PS button + Share (or Create) button together until the '
          'light bar flashes.';
    case ControllerKind.eightBitDo:
      return 'Set the controller to its Bluetooth mode, then hold Start (or the '
          'Pair button) until the LEDs flash.';
    case ControllerKind.generic:
      return 'Put the controller into Bluetooth pairing mode (usually a '
          'dedicated Pair button or a button-combo held until the light '
          'flashes), then wait for it to appear here.';
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
