import 'package:flutter/material.dart';

/// WIM-Z Premium Dark Theme - Robotics HUD Aesthetic
/// Inspired by Tesla FSD, DJI drone apps, and premium IoT interfaces
class AppTheme {
  AppTheme._();

  // ============ Brand Colors ============
  // Primary: Cyan/Teal (matches WIM-Z blue LED ring)
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF00B8D4);
  static const Color primaryLight = Color(0xFF6EFFFF);

  // Secondary: Electric Purple (for AI/detection highlights)
  static const Color secondary = Color(0xFFBB86FC);
  static const Color secondaryDark = Color(0xFF9C64FB);

  // Accent: Neon Green (success states, treats, positive actions)
  static const Color accent = Color(0xFF00FF94);
  static const Color accentDark = Color(0xFF00C853);

  // Warning/Alert
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF5252);

  // ============ Surface Colors ============
  static const Color background = Color(0xFF0A0E14);
  static const Color surface = Color(0xFF12181F);
  static const Color surfaceLight = Color(0xFF1A2332);
  static const Color surfaceLighter = Color(0xFF242D3C);

  // Glass effect colors
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // ============ Text Colors ============
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70%
  static const Color textTertiary = Color(0x80FFFFFF); // 50%
  static const Color textDisabled = Color(0x4DFFFFFF); // 30%

  // ============ Status Colors ============
  static const Color connected = Color(0xFF00FF94);
  static const Color connecting = Color(0xFFFFD600);
  static const Color disconnected = Color(0xFF6B7280);
  static const Color offline = Color(0xFFFF5252);

  // ============ Behavior Detection Colors ============
  static const Color behaviorSitting = Color(0xFF00FF94);  // Green - goal achieved
  static const Color behaviorStanding = Color(0xFFFFD600); // Yellow - neutral
  static const Color behaviorLying = Color(0xFF00E5FF);    // Cyan - relaxed
  static const Color behaviorBarking = Color(0xFFFF5252);  // Red - alert
  static const Color behaviorUnknown = Color(0xFF6B7280);  // Grey

  // ============ Gradients ============
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surfaceLight, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Glow gradient for video overlay
  static const RadialGradient glowGradient = RadialGradient(
    colors: [
      Color(0x4000E5FF),
      Color(0x0000E5FF),
    ],
    radius: 0.8,
  );

  // ============ Shadows ============
  static List<BoxShadow> glowShadow(Color color, {double blur = 20}) => [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // ============ Border Radius ============
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  // ============ Glass Card Decoration ============
  static BoxDecoration get glassCard => BoxDecoration(
        color: glassWhite,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: glassBorder, width: 1),
        boxShadow: cardShadow,
      );

  static BoxDecoration glassCardWithGlow(Color glowColor) => BoxDecoration(
        color: glassWhite,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: glowColor.withOpacity(0.3), width: 1),
        boxShadow: [
          ...cardShadow,
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      );

  // ============ Theme Data ============
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: background,
        secondary: secondary,
        onSecondary: background,
        tertiary: accent,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: textPrimary,
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Cards
      cardTheme: CardTheme(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),

      // Elevated Buttons (Primary actions)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Buttons (Secondary actions)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: background,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: surfaceLighter,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        trackHeight: 4,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withOpacity(0.5);
          return surfaceLighter;
        }),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: glassBorder,
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textTertiary),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: textTertiary, letterSpacing: 0.5),
      ),
    );
  }

  // Light theme (minimal - most users will prefer dark for this type of app)
  static ThemeData get light => dark; // Default to dark for robotics app

  // ============ Helper Methods ============

  /// Get color for behavior type with glow effect
  static Color getBehaviorColor(String? behavior) {
    switch (behavior?.toLowerCase()) {
      case 'sitting':
      case 'sit':
        return behaviorSitting;
      case 'standing':
      case 'stand':
        return behaviorStanding;
      case 'lying':
      case 'lie':
      case 'down':
        return behaviorLying;
      case 'barking':
      case 'bark':
        return behaviorBarking;
      default:
        return behaviorUnknown;
    }
  }

  /// Get color for connection status
  static Color getConnectionColor(bool isConnected, bool isConnecting) {
    if (isConnected) return connected;
    if (isConnecting) return connecting;
    return disconnected;
  }

  /// Get battery color based on level
  static Color getBatteryColor(double level) {
    if (level > 50) return accent;
    if (level > 20) return warning;
    return error;
  }
}

// ============ Custom Widgets ============

/// Glass morphism container
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? glowColor;
  final double? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.glowColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: glowColor != null
          ? AppTheme.glassCardWithGlow(glowColor!)
          : AppTheme.glassCard.copyWith(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
            ),
      child: child,
    );
  }
}

/// Neon glow text
class GlowText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? glowColor;

  const GlowText(
    this.text, {
    super.key,
    this.style,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = glowColor ?? AppTheme.primary;
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        color: color,
        shadows: [
          Shadow(color: color.withOpacity(0.8), blurRadius: 10),
          Shadow(color: color.withOpacity(0.5), blurRadius: 20),
        ],
      ),
    );
  }
}

/// Animated pulse indicator (for detection, status)
class PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final bool isActive;

  const PulseIndicator({
    super.key,
    required this.color,
    this.size = 12,
    this.isActive = true,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(_animation.value * 0.6),
                      blurRadius: widget.size * _animation.value,
                      spreadRadius: widget.size * 0.2 * _animation.value,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

/// HUD-style label (for overlays on video)
class HudLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const HudLabel({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: valueColor ?? AppTheme.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
