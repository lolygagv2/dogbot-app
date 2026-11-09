import 'package:flutter/material.dart';

/// WIM-Z brand design tokens.
///
/// The brand is black, white and gold. Lead with black and white; gold is
/// punctuation (at most ONE gold element per screen). `signal` is the only
/// cool colour and means STATUS only (online/live, links, focus ring, LED
/// chip) — never a brand colour, never a background larger than a chip.
///
/// Light = "White / Black / Gold" (primary theme). Dark = "Stealth Black".
///
/// Read it from a widget with `context.wimz.goldDeep` etc. Colours that
/// carry meaning go through [ColorScheme] slots where one fits
/// (`primary`, `onSurface`, `onSurfaceVariant`, `outline`, `outlineVariant`,
/// `surfaceContainer*`); everything brand-specific lives here.
@immutable
class WimzColors extends ThemeExtension<WimzColors> {
  // Brand constants (identical in both themes).
  final Color brandInk;
  final Color brandWhite;
  final Color brandGold;

  // Grounds.
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  // Ink.
  final Color ink;
  final Color inkMuted;
  final Color inkOnGold;
  final Color inkOnSignal;

  // Gold.
  /// Gold as TEXT or a small mark. On light grounds this is a deep gold
  /// (brand-gold is only 2.36:1 on white); on dark grounds it is brand-gold.
  final Color goldDeep;

  /// Glow / highlight on dark grounds only.
  final Color goldLight;

  // Signal (status only).
  final Color signal;

  /// Fill behind a signal chip only; never text.
  final Color signalGlow;

  // Lines.
  /// Hairline dividers and card edges.
  final Color line;

  /// Borders that carry meaning: inputs, outlined buttons, toggles.
  final Color lineStrong;

  /// Solid 2px outline, outside the control.
  final Color focus;

  /// Only for floating sheets and dialogs. Cards are flat (elevation 0).
  final BoxShadow shadowRaised;

  const WimzColors({
    required this.brandInk,
    required this.brandWhite,
    required this.brandGold,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkOnGold,
    required this.inkOnSignal,
    required this.goldDeep,
    required this.goldLight,
    required this.signal,
    required this.signalGlow,
    required this.line,
    required this.lineStrong,
    required this.focus,
    required this.shadowRaised,
  });

  /// "White / Black / Gold" — the primary theme.
  static const WimzColors light = WimzColors(
    brandInk: Color(0xFF0F0F0F),
    brandWhite: Color(0xFFFFFFFF),
    brandGold: Color(0xFFC8A45A),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF3F1F1),
    surfaceSunken: Color(0xFFD9D7D8),
    ink: Color(0xFF0F0F0F),
    inkMuted: Color(0xFF5C5A57),
    inkOnGold: Color(0xFF0F0F0F),
    inkOnSignal: Color(0xFFFFFFFF),
    goldDeep: Color(0xFF7A5C36),
    goldLight: Color(0xFFF4E3C0),
    signal: Color(0xFF3D67A9),
    signalGlow: Color(0xFFCFE7F8),
    line: Color(0xFFD1C8C5),
    lineStrong: Color(0xFF807B76),
    focus: Color(0xFF3D67A9),
    shadowRaised: BoxShadow(
      color: Color(0x1F0F0F0F), // rgba(15,15,15,.12)
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  );

  /// "Stealth Black".
  static const WimzColors dark = WimzColors(
    brandInk: Color(0xFF0F0F0F),
    brandWhite: Color(0xFFFFFFFF),
    brandGold: Color(0xFFC8A45A),
    surface: Color(0xFF0F0F0F),
    surfaceRaised: Color(0xFF1A1918),
    surfaceSunken: Color(0xFF262524),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFFA8A49F),
    inkOnGold: Color(0xFF0F0F0F),
    inkOnSignal: Color(0xFF0F0F0F),
    goldDeep: Color(0xFFC8A45A),
    goldLight: Color(0xFFF4E3C0),
    signal: Color(0xFF7ADCFA),
    signalGlow: Color(0xFF1E3A4F),
    line: Color(0xFF312E2E),
    lineStrong: Color(0xFF8C8782),
    focus: Color(0xFF7ADCFA),
    shadowRaised: BoxShadow(
      color: Color(0x99000000), // rgba(0,0,0,.6)
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  );

  // ---- Derived conveniences (no new hues) ----

  /// Disabled ink: 38% of [ink], the Material convention.
  Color get inkDisabled => ink.withValues(alpha: 0.38);

  /// Translucent ink scrim laid over video or photos so white text reads.
  /// Video is always a dark ground, so this is brand-ink in both themes.
  Color scrim([double alpha = 0.6]) => brandInk.withValues(alpha: alpha);

  /// Text / icons laid directly over video or photos.
  Color get onVideo => brandWhite;

  /// Hairline over video (line, but on the always-dark video ground).
  Color get lineOnVideo => brandWhite.withValues(alpha: 0.24);

  @override
  WimzColors copyWith({
    Color? brandInk,
    Color? brandWhite,
    Color? brandGold,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkOnGold,
    Color? inkOnSignal,
    Color? goldDeep,
    Color? goldLight,
    Color? signal,
    Color? signalGlow,
    Color? line,
    Color? lineStrong,
    Color? focus,
    BoxShadow? shadowRaised,
  }) {
    return WimzColors(
      brandInk: brandInk ?? this.brandInk,
      brandWhite: brandWhite ?? this.brandWhite,
      brandGold: brandGold ?? this.brandGold,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkOnGold: inkOnGold ?? this.inkOnGold,
      inkOnSignal: inkOnSignal ?? this.inkOnSignal,
      goldDeep: goldDeep ?? this.goldDeep,
      goldLight: goldLight ?? this.goldLight,
      signal: signal ?? this.signal,
      signalGlow: signalGlow ?? this.signalGlow,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      focus: focus ?? this.focus,
      shadowRaised: shadowRaised ?? this.shadowRaised,
    );
  }

  @override
  WimzColors lerp(ThemeExtension<WimzColors>? other, double t) {
    if (other is! WimzColors) return this;
    return WimzColors(
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandWhite: Color.lerp(brandWhite, other.brandWhite, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkOnGold: Color.lerp(inkOnGold, other.inkOnGold, t)!,
      inkOnSignal: Color.lerp(inkOnSignal, other.inkOnSignal, t)!,
      goldDeep: Color.lerp(goldDeep, other.goldDeep, t)!,
      goldLight: Color.lerp(goldLight, other.goldLight, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      signalGlow: Color.lerp(signalGlow, other.signalGlow, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      shadowRaised: BoxShadow.lerp(shadowRaised, other.shadowRaised, t)!,
    );
  }
}

/// `context.wimz.goldDeep` etc. Falls back to the dark tokens when no
/// [WimzColors] extension is installed (e.g. a widget test without a theme).
extension WimzColorsContext on BuildContext {
  WimzColors get wimz =>
      Theme.of(this).extension<WimzColors>() ??
      (Theme.of(this).brightness == Brightness.light
          ? WimzColors.light
          : WimzColors.dark);
}
