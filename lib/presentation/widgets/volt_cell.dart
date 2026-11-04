import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../painters/circuit_panel_painter.dart';

/// A single panel with its special-tile indicator, at an explicit [size].
class VoltCell extends StatelessWidget {
  const VoltCell({
    super.key,
    required this.cell,
    required this.size,
    this.glow = 1.0,
  });

  final GridCell cell;
  final double size;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final color = cell.isFilled ? Color(cell.colorHex) : null;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CircuitPanelPainter(color: color, glow: glow),
        child: switch (cell.special) {
          SpecialTile.none => null,
          SpecialTile.battery => _BatteryIndicator(size: size),
          SpecialTile.multiplier => _MultiplierBadge(
            size: size,
            color: color ?? Colors.white,
          ),
        },
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.battery_charging_full_rounded,
        size: size * 0.62,
        color: Colors.white,
        shadows: const [Shadow(color: Color(0xFFFFD600), blurRadius: 8)],
        semanticLabel: 'Battery tile',
      ),
    );
  }
}

class _MultiplierBadge extends StatelessWidget {
  const _MultiplierBadge({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size * 0.62,
        height: size * 0.42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.21),
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.18)],
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '×2',
              semanticsLabel: 'Multiplier tile',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color.lerp(color, Colors.black, 0.6),
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
