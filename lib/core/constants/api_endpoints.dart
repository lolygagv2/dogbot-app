/// All WIM-Z API endpoint paths
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String health = '/health';
  static const String telemetry = '/telemetry';
  static const String websocket = '/ws';

  // Motor control
  static const String motorSpeed = '/motor/speed';
  static const String motorStop = '/motor/stop';
  static const String motorEmergency = '/motor/emergency';

  // Camera & Servos
  static const String cameraStream = '/camera/stream';
  static const String cameraSnapshot = '/camera/snapshot';
  static const String servoPan = '/servo/pan';
  static const String servoTilt = '/servo/tilt';
  static const String servoCenter = '/servo/center';

  // Treat dispenser
  static const String treatDispense = '/treat/dispense';
  static const String treatCarouselRotate = '/treat/carousel/rotate';

  // LED control
  static const String ledPattern = '/led/pattern';
  static const String ledColor = '/led/color';
  static const String ledOff = '/led/off';

  // Audio
  static const String audioPlay = '/audio/play';
  static const String audioStop = '/audio/stop';
  static const String audioVolume = '/audio/volume';
  static const String audioFiles = '/audio/files';

  // Mode control
  static const String modeGet = '/mode/get';
  static const String modeSet = '/mode/set';

  // Missions
  static const String missions = '/missions';
  static String missionById(String id) => '/missions/$id';
  static String missionStart(String id) => '/missions/$id/start';
  static String missionStop(String id) => '/missions/$id/stop';
  static const String missionActive = '/missions/active';
  static const String missionHistory = '/missions/history';
  static const String missionStats = '/missions/stats';

  // Programs (multi-mission sequences)
  static const String programs = '/programs';

  // Dog profiles
  static const String dogs = '/api/dogs';
  static String dogDelete(String id) => '/api/dogs/$id';

  // Device pairing
  static const String userDevices = '/api/user/devices';
  static const String pairDevice = '/api/user/pair-device';
  static const String unpairDevice = '/api/user/unpair-device';

  // Scheduling (Build 34: Updated to match Robot API)
  static const String schedules = '/schedules';
  static const String scheduleEnable = '/schedules/enable';
  static const String scheduleDisable = '/schedules/disable';
  static String scheduleById(String id) => '/schedules/$id';

  // Music upload (Build 38: HTTP multipart instead of WebSocket)
  static const String musicUpload = '/api/music/upload';

  // OTA robot software updates (contract 2026-08-07; relay slice may not be
  // deployed yet — callers must treat 404 as "no releases available")
  static const String releasesLatest = '/api/releases/latest';

  // A2: Voice commands (relay-mediated; replaces direct WS upload_voice)
  static const String voiceCommands = '/api/voice-commands';
  static String voiceCommandDelete(String dogId, String commandId) =>
      '/api/voice-commands/$dogId/$commandId';

  // A3: Activity event log
  static const String activity = '/api/activity';

  // Push notifications (relay → FCM/APNs; see PUSH_NOTIFICATIONS_CONTRACT)
  static const String pushRegister = '/api/push/register';
  static const String pushUnregister = '/api/push/unregister';

  // System / WiFi (Build 66: WiFi configuration from app)
  static const String wifiScan = '/system/wifi/scan';
  static const String wifiConnect = '/system/wifi/connect';
  static const String networkStatus = '/system/network-status';

  // ---- AI Summit demo slice — relay paths per APP_BRIEF_FROM_RELAY_2026-11-06
  // (B166 aligned the B165 guesses to the shipped relay routers). Everything
  // below is dog-scoped; the relay checks owner/caretaker access on dog_id.

  /// Per-dog daily roll-up ("Today card"). [date] = YYYY-MM-DD | today |
  /// yesterday (resolved in the dog's timezone). Never 404s: an empty day
  /// comes back with event_count 0.
  static String dailySummary(String dogId, String date) =>
      '/summary/$dogId/$date';

  /// Last known robot status + treats_today/treat_cap + quiet_hours.
  static String dogStatus(String dogId) => '/api/dogs/$dogId/status';

  /// Shared per-dog settings (brief §2): GET/PUT one key → the row
  /// {key, value, version, updated_at, updated_by}; PUT body
  /// {value, expected_version?} (409 version_mismatch).
  static String dogSetting(String dogId, String key) =>
      '/api/dogs/$dogId/settings/$key';

  /// Connected AI (relay router ai.py). Assistants are per user; dog_id is
  /// for routing/access only.
  static String aiConnectors(String dogId) => '/api/dogs/$dogId/ai/connectors';
  static String aiConnectorRevoke(String dogId, String clientId) =>
      '/api/dogs/$dogId/ai/connectors/$clientId/revoke';
  static String aiRevokeAll(String dogId) => '/api/dogs/$dogId/ai/revoke_all';
  static String aiAudit(String dogId) => '/api/dogs/$dogId/ai/audit';

  /// Mission drafts (relay router mission_drafts.py): list + owner decision.
  static String missionDrafts(String dogId) =>
      '/api/dogs/$dogId/missions/drafts';
  static String missionDraft(String dogId, String draftId) =>
      '/api/dogs/$dogId/missions/drafts/$draftId';

  /// Sound library (relay router dog_settings.py): metadata / replace one
  /// (multipart `file`, ?label=&kind=sound|song) / reset ALL to builtins.
  static String dogSounds(String dogId) => '/api/dogs/$dogId/sounds';
  static String dogSoundReplace(String dogId, String soundId) =>
      '/api/dogs/$dogId/sounds/$soundId';
  static String dogSoundsReset(String dogId) => '/api/dogs/$dogId/sounds/reset';
  static String soundFile(String dogId, String soundId) =>
      '/api/sounds/file/$dogId/$soundId';

  /// Voice agent from the phone: multipart `file` (wav ≤ 30 s / 5 MB) +
  /// `dog_id` → {text_in, text_out, audio_url, clip_id, …} (brief §6).
  static const String agentUtterance = '/agent/utterance';

  /// Still attached to an event (404 none, 410 expired).
  static String eventPhoto(String dogId, String eventId) =>
      '/api/dogs/$dogId/events/$eventId/photo';
}

/// LED pattern names
class LedPatterns {
  LedPatterns._();

  static const String breathing = 'breathing';
  static const String rainbow = 'rainbow';
  static const String celebration = 'celebration';
  static const String searching = 'searching';
  static const String alert = 'alert';
  static const String warning = 'warning';
  static const String idle = 'idle';
  static const String pulse = 'pulse';
  static const String solid = 'solid';
  static const String chase = 'chase';
  static const String fire = 'fire';
  static const String solidBlue = 'solid_blue';
  static const String ambient = 'ambient';
  static const String off = 'off';

  static const List<String> all = [
    breathing,
    rainbow,
    celebration,
    searching,
    alert,
    warning,
    idle,
    pulse,
    solid,
    chase,
    fire,
    solidBlue,
    ambient,
    off,
  ];

  /// Patterns for cycling through in the Lighting button
  /// Order: rainbow, fire, solid_blue, chase, ambient, off
  static const List<String> lightingCycle = [
    rainbow,
    fire,
    solidBlue,
    chase,
    ambient,
    off,
  ];
}

/// Robot operating modes
class RobotModes {
  RobotModes._();

  static const String idle = 'idle';
  static const String guardian = 'guardian';
  static const String training = 'training';
  static const String manual = 'manual';
  static const String docking = 'docking';

  static const List<String> all = [
    idle,
    guardian,
    training,
    manual,
    docking,
  ];
}
