import 'package:flutter/material.dart';

import '../../theme/wimz_theme.dart';

export '../../theme/wimz_theme.dart';

/// Legacy entry point kept for the existing imports.
///
/// Colour now lives in `lib/theme/` ([WimzColors] tokens, [WimzTheme]
/// ThemeData, [WimzStatus] status maps). Nothing here holds a colour: read
/// them from `Theme.of(context).colorScheme` or `context.wimz` so light and
/// dark both resolve correctly.
class AppTheme {
  AppTheme._();

  // ============ Border Radius ============
  static const double radiusSmall = WimzTheme.radiusSmall;
  static const double radiusMedium = WimzTheme.radiusMedium;
  static const double radiusLarge = WimzTheme.radiusLarge;
  static const double radiusXLarge = WimzTheme.radiusXLarge;

  // ============ Theme Data ============
  static ThemeData get light => WimzTheme.light;
  static ThemeData get dark => WimzTheme.dark;

  // ============ Helper Methods ============

  /// Get display name for behavior (dog training terminology)
  static String getBehaviorDisplayName(String? behavior) {
    if (behavior == null) return 'Dog';
    switch (behavior.toLowerCase()) {
      case 'sit':
      case 'sitting':
        return 'Sit';
      case 'laydown':
      case 'down':
      case 'lying':
      case 'lie':
      case 'lie_down':
        return 'Lay Down';
      case 'come':
      case 'stand':
      case 'standing':
        return 'Come';
      case 'spin':
        return 'Spin';
      case 'speak':
        return 'Speak';
      case 'bark':
      case 'barking':
        return 'Bark';
      default:
        return behavior;
    }
  }
}

// ============ Custom Widgets ============

/// Flat brand card: surface-raised fill, 1px line edge, elevation 0.
/// `glowColor`, when given, becomes the border colour (a status edge) —
/// never a glow.
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
      decoration: WimzTheme.cardDecoration(
        context,
        radius: borderRadius ?? AppTheme.radiusMedium,
        borderColor: glowColor,
      ),
      child: child,
    );
  }
}

/// Emphasised text. Formerly neon-glow; now plain ink (or the colour given)
/// with no shadow — the brand has no glow on light grounds.
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
    final color = glowColor ?? context.wimz.ink;
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}

/// Animated pulse indicator (for detection, status). Pair it with a word or
/// icon — colour alone never carries the status.
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
        return Opacity(
          opacity: widget.isActive ? _animation.value : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

/// HUD-style label (for overlays on video). Video is an always-dark ground,
/// so this uses the ink scrim with white text in both themes.
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
    final c = context.wimz;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.scrim(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.lineOnVideo),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: valueColor ?? c.onVideo),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: c.onVideo.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? c.onVideo,
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
