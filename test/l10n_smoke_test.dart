import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/l10n/l10n.dart';

void main() {
  test('ko and en ARBs have identical key sets', () {
    final en = json.decode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final ko = json.decode(File('lib/l10n/app_ko.arb').readAsStringSync()) as Map;
    Set<String> keys(Map m) =>
        m.keys.cast<String>().where((k) => !k.startsWith('@')).toSet();
    expect(keys(ko), equals(keys(en)));
  });

  test('Korean lookup resolves without a BuildContext', () {
    final ko = lookupAppLocalizations(const Locale('ko'));
    expect(ko.cancel, '취소');
    expect(ko.settings, '설정');
    expect(lookupAppLocalizations(const Locale('en')).cancel, 'Cancel');
  });

  testWidgets('MaterialApp renders Korean when locale is ko', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Text(context.l10n.language)),
      ),
    );
    expect(find.text('언어'), findsOneWidget);
  });
}
