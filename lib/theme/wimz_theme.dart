import 'package:flutter/material.dart';

import 'wimz_colors.dart';

export 'wimz_colors.dart';

/// WIM-Z brand themes: "White / Black / Gold" (light, primary) and
/// "Stealth Black" (dark). Material 3 with an explicit [ColorScheme] (not
/// `fromSeed`) so every slot maps to a brand token.
///
/// Component rules (brand design system):
/// - FilledButton / ElevatedButton = primary (ink in light, white in dark),
///   quiet by default. The ONE gold hero CTA per screen uses [goldButtonStyle].
/// - OutlinedButton border = line-strong. Cards = surface-raised, 1px line,
///   elevation 0, no shadow. Inputs = surface-raised fill, line-strong border,
///   focus border = signal. Dividers = line.
/// - AppBar / NavigationBar = surface ground, ink foreground, selected
///   indicator NOT gold. Switches / checkboxes active = primary.
/// - `error` / `onError` are the pre-rebrand values (the brand defines no red);
///   every error state must also carry an icon and a word.
class WimzTheme {
  WimzTheme._();

  // The pre-rebrand error slot, kept as-is (the brand defines no red).
  static const Color _error = Color(0xFFFF5252);
  static const Color _onError = Color(0xFFFFFFFF);

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  static ThemeData get light => _build(Brightness.light, WimzColors.light);
  static ThemeData get dark => _build(Brightness.dark, WimzColors.dark);

  static ColorScheme _scheme(Brightness b, WimzColors c) {
    final isLight = b == Brightness.light;
    return ColorScheme(
      brightness: b,
      // Light: ink on white. Dark: white on black (brand-ink would vanish).
      primary: isLight ? c.brandInk : c.brandWhite,
      onPrimary: isLight ? c.brandWhite : c.brandInk,
      primaryContainer: c.surfaceSunken,
      onPrimaryContainer: c.ink,
      secondary: c.brandGold,
      onSecondary: c.inkOnGold,
      secondaryContainer: c.surfaceSunken,
      onSecondaryContainer: c.ink,
      tertiary: c.signal,
      onTertiary: c.inkOnSignal,
      tertiaryContainer: c.signalGlow,
      onTertiaryContainer: c.signal,
      error: _error,
      onError: _onError,
      errorContainer: c.surfaceRaised,
      onErrorContainer: _error,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceDim: c.surfaceSunken,
      surfaceBright: c.surface,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceSunken,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.lineStrong,
      outlineVariant: c.line,
      shadow: c.shadowRaised.color,
      scrim: c.brandInk,
      inverseSurface: isLight ? c.brandInk : c.brandWhite,
      onInverseSurface: isLight ? c.brandWhite : c.brandInk,
      inversePrimary: isLight ? c.brandWhite : c.brandInk,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness b, WimzColors c) {
    final cs = _scheme(b, c);
    final roundedSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    );
    final roundedMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    );
    // Every text style is derived from the platform typography so it keeps
    // the platform font family (Roboto / SF) rather than an unset family.
    final base = ThemeData(brightness: b, useMaterial3: true).textTheme;
    final textTheme = _textTheme(base, c);
    final buttonText = base.labelLarge!
        .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: cs,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      dividerColor: c.line,
      focusColor: c.focus,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: base.titleLarge!.copyWith(
          color: c.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: c.ink),
        actionsIconTheme: IconThemeData(color: c.ink),
      ),

      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: c.line, width: 1),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: roundedSmall,
          textStyle: buttonText,
        ),
      ),

      // ElevatedButton is used as the "primary action" throughout the app;
      // it renders the same as FilledButton (flat, primary fill).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: roundedSmall,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          disabledForegroundColor: c.inkDisabled,
          side: BorderSide(color: c.lineStrong, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: roundedSmall,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          disabledForegroundColor: c.inkDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          disabledForegroundColor: c.inkDisabled,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        // Stadium works for both the round FAB and FAB.extended (a circle
        // clips the extended label).
        shape: const StadiumBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.lineStrong),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
        labelStyle: TextStyle(color: c.inkMuted),
        hintStyle: TextStyle(color: c.inkMuted),
        helperStyle: TextStyle(color: c.inkMuted),
        prefixIconColor: c.inkMuted,
        suffixIconColor: c.inkMuted,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.ink,
        unselectedItemColor: c.inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.surfaceSunken,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.ink : c.inkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? c.ink : c.inkMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.inkMuted,
        indicatorColor: c.ink,
        dividerColor: c.line,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: c.surfaceSunken,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.inkDisabled;
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          return c.lineStrong;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.surfaceSunken;
          if (states.contains(WidgetState.selected)) return cs.primary;
          return c.surfaceRaised;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return c.lineStrong;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(cs.onPrimary),
        side: BorderSide(color: c.lineStrong, width: 1.5),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return c.lineStrong;
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.surfaceSunken,
        disabledColor: c.surfaceRaised,
        labelStyle: TextStyle(color: c.ink),
        secondaryLabelStyle: TextStyle(color: c.ink),
        side: BorderSide(color: c.line),
        shape: roundedSmall,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: c.ink,
        iconTheme: IconThemeData(color: c.ink, size: 18),
      ),

      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        textColor: c.ink,
        tileColor: Colors.transparent,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadowRaised.color,
        shape: roundedMedium,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        elevation: 8,
        shadowColor: c.shadowRaised.color,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadowRaised.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: BorderSide(color: c.line),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        actionTextColor: cs.onInverseSurface,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: roundedSmall,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(BorderSide(color: c.lineStrong)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return cs.primary;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return cs.onPrimary;
            return c.ink;
          }),
        ),
      ),

      iconTheme: IconThemeData(color: c.ink, size: 24),
      primaryIconTheme: IconThemeData(color: c.ink, size: 24),
    );
  }

  static TextTheme _textTheme(TextTheme t, WimzColors c) {
    TextStyle s(TextStyle? style, Color color,
            {FontWeight? weight, double? spacing}) =>
        style!
            .copyWith(color: color, fontWeight: weight, letterSpacing: spacing);
    return TextTheme(
      displayLarge: s(t.displayLarge, c.ink, weight: FontWeight.w700),
      displayMedium: s(t.displayMedium, c.ink, weight: FontWeight.w700),
      displaySmall: s(t.displaySmall, c.ink, weight: FontWeight.w600),
      headlineLarge: s(t.headlineLarge, c.ink, weight: FontWeight.w600),
      headlineMedium: s(t.headlineMedium, c.ink, weight: FontWeight.w600),
      headlineSmall: s(t.headlineSmall, c.ink, weight: FontWeight.w600),
      titleLarge: s(t.titleLarge, c.ink, weight: FontWeight.w600),
      titleMedium: s(t.titleMedium, c.ink, weight: FontWeight.w500),
      titleSmall: s(t.titleSmall, c.inkMuted, weight: FontWeight.w500),
      bodyLarge: s(t.bodyLarge, c.ink),
      bodyMedium: s(t.bodyMedium, c.inkMuted),
      bodySmall: s(t.bodySmall, c.inkMuted),
      labelLarge: s(t.labelLarge, c.ink, weight: FontWeight.w600, spacing: 0.5),
      labelMedium: s(t.labelMedium, c.inkMuted, weight: FontWeight.w500),
      labelSmall: s(t.labelSmall, c.inkMuted, spacing: 0.5),
    );
  }

  // ---------------------------------------------------------------------
  // Brand helpers
  // ---------------------------------------------------------------------

  /// The ONE gold hero CTA allowed per screen: brand-gold fill, ink-on-gold
  /// text. Never white on gold. Works for FilledButton and ElevatedButton.
  static ButtonStyle goldButtonStyle(BuildContext context) {
    final c = context.wimz;
    return FilledButton.styleFrom(
      backgroundColor: c.brandGold,
      foregroundColor: c.inkOnGold,
      disabledBackgroundColor: c.surfaceSunken,
      disabledForegroundColor: c.inkDisabled,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      textStyle: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  /// Flat brand card: surface-raised fill, 1px line edge, no shadow.
  static BoxDecoration cardDecoration(BuildContext context,
      {double radius = radiusMedium, Color? borderColor}) {
    final c = context.wimz;
    return BoxDecoration(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? c.line, width: 1),
    );
  }

  /// Status chip (online / live / LED ring): signal-glow fill, signal text
  /// and icon. The only place `signalGlow` is used as a fill.
  static BoxDecoration statusChipDecoration(BuildContext context,
      {double radius = 999}) {
    final c = context.wimz;
    return BoxDecoration(
      color: c.signalGlow,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Decoration for a floating sheet / dialog / overlay panel (the only
  /// place shadow-raised is allowed).
  static BoxDecoration raisedDecoration(BuildContext context,
      {double radius = radiusMedium}) {
    final c = context.wimz;
    return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.line, width: 1),
      boxShadow: [c.shadowRaised],
    );
  }

  /// Solid 2px focus outline drawn outside a control.
  static BoxDecoration focusRing(BuildContext context, bool focused,
      {double radius = radiusSmall}) {
    final c = context.wimz;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius + 2),
      border: Border.all(
        color: focused ? c.focus : Colors.transparent,
        width: 2,
      ),
    );
  }
}

/// Status → colour maps. Every status is ALSO shown with a word or icon by
/// the calling widget; colour alone never carries meaning.
class WimzStatus {
  WimzStatus._();

  /// Tokens for marks drawn directly over video or photos. Video is an
  /// always-dark ground, so the "Stealth Black" set is used in both themes
  /// (light-theme ink would be black on black).
  static WimzColors _tokens(BuildContext context, bool onVideo) =>
      onVideo ? WimzColors.dark : context.wimz;

  /// Per-dog differentiation palette for multi-dog detection boxes / chips.
  /// No gold (the screen's single gold element is its CTA); every box also
  /// prints the dog's name.
  static List<Color> dogPalette(BuildContext context, {bool onVideo = false}) {
    final c = _tokens(context, onVideo);
    return [
      c.ink,
      c.inkMuted,
      c.signal,
      c.lineStrong,
      Theme.of(context).colorScheme.error,
    ];
  }

  /// Detected dog behaviour. Re-mapped to ink / ink-muted / signal / error;
  /// the overlay always prints the behaviour name beside the box. Pass
  /// `onVideo: true` for marks drawn over the camera feed.
  static Color behavior(BuildContext context, String? behavior,
      {bool onVideo = false}) {
    final c = _tokens(context, onVideo);
    switch (behavior?.toLowerCase()) {
      case 'sitting':
      case 'sit':
      case 'laydown':
      case 'lying':
      case 'lie':
      case 'down':
        return c.ink; // goal / settled
      case 'come':
      case 'standing':
      case 'stand':
      case 'spin':
      case 'speak':
        return c.inkMuted; // neutral / in progress
      case 'barking':
      case 'bark':
        return Theme.of(context).colorScheme.error; // alert (with label)
      default:
        return c.inkMuted;
    }
  }

  /// Bark-type (SG reporting group) colours — fixed per type, shared by the
  /// SG summary card and the dog profile breakdown so a type always wears the
  /// same colour. Both callers draw a legend label next to every swatch.
  static Color barkType(BuildContext context, String type) {
    final c = context.wimz;
    switch (type) {
      case 'aggressive':
        return Theme.of(context).colorScheme.error;
      case 'alarm':
        return c.goldDeep;
      case 'distress':
        return c.ink;
      case 'demand':
        return c.signal;
      case 'play':
        return c.inkMuted;
      case 'unclassified':
      default:
        return c.lineStrong;
    }
  }

  /// Fixed order of bark types, for legends.
  static const List<String> barkTypes = [
    'distress',
    'demand',
    'alarm',
    'aggressive',
    'play',
    'unclassified',
  ];

  /// Battery: ink while healthy, ink-muted when getting low, error when
  /// critical. The indicator always shows the percentage and a battery icon.
  /// (No gold here: the battery chip sits on screens that already spend
  /// their one gold element on a CTA.)
  static Color battery(BuildContext context, double level) {
    final c = context.wimz;
    if (level > 50) return c.ink;
    if (level > 20) return c.inkMuted;
    return Theme.of(context).colorScheme.error;
  }

  /// Connection: signal = online/live (status), ink-muted = connecting or
  /// disconnected. Callers show the state word too.
  static Color connection(BuildContext context,
      {required bool isConnected, required bool isConnecting}) {
    final c = context.wimz;
    if (isConnected) return c.signal;
    return c.inkMuted;
  }
}
