/// Localization entry point.
///
/// Import this file (not `app_localizations.dart` directly) from widgets and
/// use `context.l10n.someKey`. Strings live in `app_en.arb` (template) and
/// `app_ko.arb`; run `flutter gen-l10n` (or any `flutter run`/`build`) after
/// editing them to regenerate `app_localizations*.dart`.
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'model_labels.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
