/// Maps a relay push payload's `data` to the in-app route a tap should open.
///
/// Relay pushes (PUSH_NOTIFICATIONS_CONTRACT) carry `data: {type, dog_id,
/// kind?, actor?}`. Known kinds:
/// - `treat_limit_raised` (brief 2026-11-09 §5): Claude / the voice agent
///   raised a cap → Settings → Daily treat limit, so the owner can put it
///   back.
/// Anything else lands on the Notifications tab; null when the payload
/// isn't a relay push at all.
String? pushRouteFor(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return null;
  final kind = data['kind']?.toString();
  switch (kind) {
    case kPushKindTreatLimitRaised:
      return kSettingsTreatLimitRoute;
  }
  final type = data['type']?.toString();
  if (type == null || type.isEmpty) return null;
  return '/activity';
}

const String kPushKindTreatLimitRaised = 'treat_limit_raised';

/// Settings screen with the Daily treat limit tile scrolled into view and
/// highlighted (`focus` query param read by SettingsScreen).
const String kSettingsTreatLimitRoute = '/settings?focus=treat_limit';
const String kSettingsFocusTreatLimit = 'treat_limit';
