// Brand theme smoke test: both WIM-Z themes install the WimzColors extension
// and the colour pairs the brand rules depend on actually meet WCAG AA
// (4.5:1 for text). Replaces the Flutter counter boilerplate, which referenced
// a `MyApp` class this app never had.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/theme/wimz_theme.dart';

double _luminance(Color c) {
  double chan(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('WimzTheme', () {
    for (final entry in {
      'light': (WimzTheme.light, WimzColors.light),
      'dark': (WimzTheme.dark, WimzColors.dark),
    }.entries) {
      final name = entry.key;
      final theme = entry.value.$1;
      final tokens = entry.value.$2;

      test('$name theme installs WimzColors and an explicit scheme', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.extension<WimzColors>(), same(tokens));
        expect(theme.colorScheme.surface, tokens.surface);
        expect(theme.colorScheme.onSurface, tokens.ink);
        expect(theme.colorScheme.onSurfaceVariant, tokens.inkMuted);
        expect(theme.colorScheme.secondary, tokens.brandGold);
        expect(theme.colorScheme.onSecondary, tokens.inkOnGold);
        expect(theme.colorScheme.tertiary, tokens.signal);
        expect(theme.colorScheme.outline, tokens.lineStrong);
        expect(theme.colorScheme.outlineVariant, tokens.line);
        // Cards are flat.
        expect(theme.cardTheme.elevation, 0);
      });

      test('$name tokens meet AA where the brand uses them as text', () {
        // Ink and muted ink on every ground.
        for (final ground in [
          tokens.surface,
          tokens.surfaceRaised,
          tokens.surfaceSunken,
        ]) {
          expect(contrast(tokens.ink, ground), greaterThanOrEqualTo(4.5));
          expect(contrast(tokens.inkMuted, ground), greaterThanOrEqualTo(4.5));
        }
        // Gold as text uses gold-deep, never brand-gold on light.
        expect(contrast(tokens.goldDeep, tokens.surface),
            greaterThanOrEqualTo(4.5));
        // Ink-on-gold on a brand-gold fill (never white on gold).
        expect(contrast(tokens.inkOnGold, tokens.brandGold),
            greaterThanOrEqualTo(4.5));
        expect(contrast(tokens.brandWhite, tokens.brandGold), lessThan(4.5),
            reason: 'white on gold must stay forbidden');
        // Signal is a status mark (icon / chip / link), never body text:
        // in light, signal on white and on its own chip fill are both
        // 4.43:1, so hold it to the 3:1 bar for UI components / large text.
        expect(contrast(tokens.signal, tokens.surface),
            greaterThanOrEqualTo(3.0));
        expect(contrast(tokens.signal, tokens.signalGlow),
            greaterThanOrEqualTo(3.0));
        // Primary button text.
        expect(
            contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
            greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('context.wimz resolves per theme', (tester) async {
      late WimzColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: WimzTheme.light,
        darkTheme: WimzTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(builder: (context) {
          seen = context.wimz;
          return const SizedBox();
        }),
      ));
      expect(seen.surface, WimzColors.dark.surface);
      expect(seen.goldDeep, WimzColors.dark.brandGold,
          reason: 'on dark grounds gold text is brand-gold');
    });
  });
}
