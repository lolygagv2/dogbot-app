/// Robot sound catalog for Settings → Advanced → Sounds.
///
/// The ids below are the app's default catalog (contract
/// `.claude/APP_CONTRACT_AI_SUMMIT_DEMO_2026-11-05.md` §3). When the robot
/// answers GET /api/sounds its list wins — ids it reports that we don't know
/// are shown under their reported group; ids we know that it omits are still
/// listed (replace is a plain upload by id either way).
enum SoundGroup { greeting, treat, cue, alert, sgLevel, music }

class SoundSlot {
  final String id;
  final SoundGroup group;

  /// Robot-provided label (when the catalog came from the robot); null →
  /// the app derives one from the id.
  final String? label;

  /// True when the owner replaced the factory file for this id.
  final bool custom;
  final DateTime? updatedAt;

  const SoundSlot({
    required this.id,
    required this.group,
    this.label,
    this.custom = false,
    this.updatedAt,
  });

  SoundSlot copyWith({bool? custom, DateTime? updatedAt, String? label}) =>
      SoundSlot(
        id: id,
        group: group,
        label: label ?? this.label,
        custom: custom ?? this.custom,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static SoundGroup groupFromWire(String? g, String id) {
    switch ((g ?? '').toLowerCase()) {
      case 'greeting':
        return SoundGroup.greeting;
      case 'treat':
      case 'reward':
        return SoundGroup.treat;
      case 'cue':
      case 'command':
        return SoundGroup.cue;
      case 'alert':
      case 'alarm':
        return SoundGroup.alert;
      case 'sg':
      case 'sg_level':
      case 'guardian':
        return SoundGroup.sgLevel;
      case 'music':
      case 'music_class':
        return SoundGroup.music;
    }
    // Infer from id prefix for robots that send a flat list.
    if (id.startsWith('sg_')) return SoundGroup.sgLevel;
    if (id.startsWith('music_')) return SoundGroup.music;
    if (id.startsWith('cue_')) return SoundGroup.cue;
    if (id.startsWith('greet')) return SoundGroup.greeting;
    if (id.contains('alert') || id.contains('alarm') || id.contains('battery')) {
      return SoundGroup.alert;
    }
    if (id.contains('treat') || id == 'good') return SoundGroup.treat;
    return SoundGroup.cue;
  }
}

/// Default catalog — every sound id the robot plays, grouped.
const List<SoundSlot> kDefaultSoundCatalog = [
  SoundSlot(id: 'greeting', group: SoundGroup.greeting),
  SoundSlot(id: 'treat', group: SoundGroup.treat),
  SoundSlot(id: 'good', group: SoundGroup.treat),
  SoundSlot(id: 'cue_sit', group: SoundGroup.cue),
  SoundSlot(id: 'cue_down', group: SoundGroup.cue),
  SoundSlot(id: 'cue_come', group: SoundGroup.cue),
  SoundSlot(id: 'cue_stay', group: SoundGroup.cue),
  SoundSlot(id: 'cue_quiet', group: SoundGroup.cue),
  SoundSlot(id: 'cue_no', group: SoundGroup.cue),
  SoundSlot(id: 'alert', group: SoundGroup.alert),
  SoundSlot(id: 'low_battery', group: SoundGroup.alert),
  SoundSlot(id: 'sg_level_1', group: SoundGroup.sgLevel),
  SoundSlot(id: 'sg_level_2', group: SoundGroup.sgLevel),
  SoundSlot(id: 'sg_level_3', group: SoundGroup.sgLevel),
  SoundSlot(id: 'sg_level_4', group: SoundGroup.sgLevel),
  SoundSlot(id: 'music_calm', group: SoundGroup.music),
  SoundSlot(id: 'music_play', group: SoundGroup.music),
  SoundSlot(id: 'music_sleep', group: SoundGroup.music),
  SoundSlot(id: 'music_focus', group: SoundGroup.music),
];
