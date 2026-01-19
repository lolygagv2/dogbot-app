import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../theme/app_theme.dart';

/// Premium circular gauge for battery, speed, or other metrics
class WimzGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String? unit;
  final Color? color;
  final double size;
  final bool showPointer;

  const WimzGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    required this.label,
    this.unit,
    this.color,
    this.size = 120,
    this.showPointer = true,
  });

  @override
  Widget build(BuildContext context) {
    final gaugeColor = color ?? _getColorForValue(value);

    return SizedBox(
      width: size,
      height: size,
      child: SfRadialGauge(
        axes: [
          RadialAxis(
            minimum: min,
            maximum: max,
            startAngle: 135,
            endAngle: 45,
            showLabels: false,
            showTicks: false,
            radiusFactor: 0.9,
            axisLineStyle: AxisLineStyle(
              thickness: 0.12,
              thicknessUnit: GaugeSizeUnit.factor,
              color: AppTheme.surfaceLighter,
              cornerStyle: CornerStyle.bothCurve,
            ),
            pointers: [
              // Value arc
              RangePointer(
                value: value,
                width: 0.12,
                sizeUnit: GaugeSizeUnit.factor,
                color: gaugeColor,
                cornerStyle: CornerStyle.bothCurve,
                gradient: SweepGradient(
                  colors: [
                    gaugeColor.withOpacity(0.6),
                    gaugeColor,
                  ],
                ),
              ),
              // Needle pointer (optional)
              if (showPointer)
                NeedlePointer(
                  value: value,
                  needleLength: 0.6,
                  needleStartWidth: 1,
                  needleEndWidth: 3,
                  needleColor: gaugeColor,
                  knobStyle: KnobStyle(
                    knobRadius: 0.08,
                    color: gaugeColor,
                    borderColor: AppTheme.surface,
                    borderWidth: 0.02,
                    sizeUnit: GaugeSizeUnit.factor,
                  ),
                ),
            ],
            annotations: [
              // Value text
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.bold,
                        color: gaugeColor,
                        fontFamily: 'SpaceMono',
                        shadows: AppTheme.glowShadow(gaugeColor, blur: 10)
                            .map((s) => Shadow(
                                  color: s.color,
                                  blurRadius: s.blurRadius,
                                ))
                            .toList(),
                      ),
                    ),
                    if (unit != null)
                      Text(
                        unit!,
                        style: TextStyle(
                          fontSize: size * 0.1,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
                angle: 90,
                positionFactor: 0.1,
              ),
              // Label
              GaugeAnnotation(
                widget: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.09,
                    color: AppTheme.textTertiary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                angle: 90,
                positionFactor: 0.75,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(double val) {
    final percent = (val - min) / (max - min);
    if (percent > 0.6) return AppTheme.accent;
    if (percent > 0.3) return AppTheme.warning;
    return AppTheme.error;
  }
}

/// Battery gauge with specific styling
class BatteryGauge extends StatelessWidget {
  final double level;
  final bool isCharging;
  final double size;

  const BatteryGauge({
    super.key,
    required this.level,
    this.isCharging = false,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        WimzGauge(
          value: level,
          min: 0,
          max: 100,
          label: isCharging ? 'CHARGING' : 'BATTERY',
          unit: '%',
          size: size,
          showPointer: false,
        ),
        if (isCharging)
          Positioned(
            bottom: size * 0.15,
            child: Icon(
              Icons.bolt,
              color: AppTheme.warning,
              size: size * 0.15,
            ),
          ),
      ],
    );
  }
}

/// Speed gauge for motor output
class SpeedGauge extends StatelessWidget {
  final double leftSpeed;
  final double rightSpeed;
  final double size;

  const SpeedGauge({
    super.key,
    required this.leftSpeed,
    required this.rightSpeed,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SingleSpeedGauge(
          value: leftSpeed,
          label: 'L',
          size: size,
        ),
        SizedBox(width: size * 0.1),
        _SingleSpeedGauge(
          value: rightSpeed,
          label: 'R',
          size: size,
        ),
      ],
    );
  }
}

class _SingleSpeedGauge extends StatelessWidget {
  final double value;
  final String label;
  final double size;

  const _SingleSpeedGauge({
    required this.value,
    required this.label,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isForward = value >= 0;
    final absValue = value.abs() * 100;
    final color = isForward ? AppTheme.accent : AppTheme.error;

    return SizedBox(
      width: size,
      height: size,
      child: SfRadialGauge(
        axes: [
          RadialAxis(
            minimum: 0,
            maximum: 100,
            startAngle: 180,
            endAngle: 0,
            showLabels: false,
            showTicks: false,
            radiusFactor: 0.9,
            axisLineStyle: AxisLineStyle(
              thickness: 0.15,
              thicknessUnit: GaugeSizeUnit.factor,
              color: AppTheme.surfaceLighter,
              cornerStyle: CornerStyle.bothCurve,
            ),
            pointers: [
              RangePointer(
                value: absValue,
                width: 0.15,
                sizeUnit: GaugeSizeUnit.factor,
                color: color,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: [
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: size * 0.2,
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: size * 0.15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0.5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
