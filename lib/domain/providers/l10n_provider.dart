import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'locale_provider.dart';

/// [AppLocalizations] for code that has no [BuildContext] (providers that
/// build notification titles, error messages, etc.). Follows Settings →
/// Language, or the device locale when that is "system default".
///
/// Widgets should keep using `context.l10n`; this is for the domain layer.
final l10nProvider = Provider<AppLocalizations>((ref) {
  final chosen = ref.watch(localeProvider);
  return lookupAppLocalizations(chosen ?? _deviceLocale());
});

Locale _deviceLocale() {
  const supported = AppLocalizations.supportedLocales;
  for (final l in WidgetsBinding.instance.platformDispatcher.locales) {
    for (final s in supported) {
      if (s.languageCode == l.languageCode) return s;
    }
  }
  return supported.first; // en
}
