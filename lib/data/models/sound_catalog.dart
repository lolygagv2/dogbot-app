/// Sound library for Settings → Advanced → Sounds.
///
/// Cloud: the relay's per-dog `sounds` setting (`GET /api/dogs/{dog}/sounds`
/// → `{sounds:[{id, kind sound|song, label, builtin, file, url}]}`). Builtins
/// are `chime`, `whistle`, `shush`, `good_dog` (sounds) and `song_calm_01`,
/// `song_calm_02` (songs); `builtin:false` rows were uploaded by the owner.
/// Local-AP: the robot's `GET /sounds` (groups of stems; replace/reset per
/// `/sounds/{group}/{stem}/…`). The server catalog always wins; the default
/// list below is only shown when neither answers.
enum SoundKind { sound, song }

enum SoundGroup { greeting, treat, cue, alert, sgLevel, music, song }

class SoundSlot {
  final String id;
  final SoundGroup group;
  final SoundKind kind;

  /// Server-provided label; null → the app derives one from the id.
  final String? label;

  /// True when the owner replaced the factory file for this id.
  final bool custom;
  final DateTime? updatedAt;
  final String? url;
  final String? file;

  /// Robot-local addressing (`/sounds/{group}/{stem}/…`); null in cloud.
  final String? robotGroup;
  final String? stem;

  const SoundSlot({
    required this.id,
    required this.group,
    this.kind = SoundKind.sound,
    this.label,
    this.custom = false,
    this.updatedAt,
    this.url,
    this.file,
    this.robotGroup,
    this.stem,
  });

  SoundSlot copyWith({bool? custom, DateTime? updatedAt, String? label}) =>
      SoundSlot(
        id: id,
        group: group,
        kind: kind,
        label: label ?? this.label,
        custom: custom ?? this.custom,
        updatedAt: updatedAt ?? this.updatedAt,
        url: url,
        file: file,
        robotGroup: robotGroup,
        stem: stem,
      );

  /// Relay `sounds` setting row.
  static SoundSlot? fromRelay(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final kind = kindFromWire(j['kind']?.toString()) ??
        (id.startsWith('song') ? SoundKind.song : SoundKind.sound);
    final label = j['label']?.toString();
    return SoundSlot(
      id: id,
      kind: kind,
      group: kind == SoundKind.song
          ? SoundGroup.song
          : groupFromWire(j['group']?.toString(), id),
      label: (label == null || label.isEmpty) ? null : label,
      custom: j['builtin'] == false || j['custom'] == true,
      url: j['url']?.toString(),
      file: j['file']?.toString(),
    );
  }

  /// Robot-local catalog row (lenient: `{group, stem|id|name, custom|override|
  /// builtin, label}`), [groupKey] when the robot nests rows under groups.
  static SoundSlot? fromRobot(Map<String, dynamic> j, {String? groupKey}) {
    final group = (j['group'] ?? groupKey)?.toString();
    final stem = (j['stem'] ?? j['name'] ?? j['id'])?.toString();
    if (stem == null || stem.isEmpty) return null;
    final id = (group != null && group.isNotEmpty && !stem.contains('/'))
        ? '$group/$stem'
        : stem;
    final kind = kindFromWire(j['kind']?.toString()) ??
        ((group ?? '').contains('song') || (group ?? '').contains('music')
            ? SoundKind.song
            : SoundKind.sound);
    final label = j['label']?.toString();
    return SoundSlot(
      id: id,
      kind: kind,
      group: kind == SoundKind.song ? SoundGroup.song : groupFromWire(group, stem),
      label: (label == null || label.isEmpty) ? null : label,
      custom: j['custom'] == true ||
          j['override'] == true ||
          j['builtin'] == false ||
          j['source']?.toString() == 'custom',
      robotGroup: group,
      stem: stem.contains('/') ? stem.split('/').last : stem,
    );
  }

  static SoundKind? kindFromWire(String? k) => switch (k?.toLowerCase()) {
        'song' || 'music' => SoundKind.song,
        'sound' => SoundKind.sound,
        _ => null,
      };

  static SoundGroup groupFromWire(String? g, String id) {
    switch ((g ?? '').toLowerCase()) {
      case 'greeting':
      case 'greetings':
        return SoundGroup.greeting;
      case 'treat':
      case 'reward':
      case 'rewards':
      case 'praise':
        return SoundGroup.treat;
      case 'cue':
      case 'cues':
      case 'command':
      case 'commands':
        return SoundGroup.cue;
      case 'alert':
      case 'alerts':
      case 'alarm':
        return SoundGroup.alert;
      case 'sg':
      case 'sg_level':
      case 'guardian':
      case 'silent_guardian':
        return SoundGroup.sgLevel;
      case 'music':
      case 'music_class':
        return SoundGroup.music;
      case 'song':
      case 'songs':
        return SoundGroup.song;
    }
    // Infer from the id for flat lists.
    final s = id.toLowerCase();
    if (s.startsWith('song')) return SoundGroup.song;
    if (s.startsWith('sg_') || s == 'shush' || s.contains('quiet')) {
      return SoundGroup.sgLevel;
    }
    if (s.startsWith('music_')) return SoundGroup.music;
    if (s.startsWith('cue_') || s == 'whistle' || s == 'chime') {
      return SoundGroup.cue;
    }
    if (s.startsWith('greet')) return SoundGroup.greeting;
    if (s.contains('alert') || s.contains('alarm') || s.contains('battery')) {
      return SoundGroup.alert;
    }
    if (s.contains('treat') || s.contains('good')) return SoundGroup.treat;
    return SoundGroup.cue;
  }
}

/// Relay builtins — shown only when no server catalog is available.
const List<SoundSlot> kDefaultSoundCatalog = [
  SoundSlot(id: 'chime', group: SoundGroup.cue),
  SoundSlot(id: 'whistle', group: SoundGroup.cue),
  SoundSlot(id: 'shush', group: SoundGroup.sgLevel),
  SoundSlot(id: 'good_dog', group: SoundGroup.treat),
  SoundSlot(id: 'song_calm_01', group: SoundGroup.song, kind: SoundKind.song),
  SoundSlot(id: 'song_calm_02', group: SoundGroup.song, kind: SoundKind.song),
];

/// Relay accepts `^[a-zA-Z0-9_-]{1,64}$` sound ids. Build one from a file
/// name: "My Calm Song.mp3" → "song_my_calm_song".
String soundIdFromFilename(String filename, {String prefix = 'song_'}) {
  final stem = filename.contains('.')
      ? filename.substring(0, filename.lastIndexOf('.'))
      : filename;
  var slug = stem
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.isEmpty) slug = DateTime.now().millisecondsSinceEpoch.toString();
  final id = '$prefix$slug';
  return id.length > 64 ? id.substring(0, 64) : id;
}
