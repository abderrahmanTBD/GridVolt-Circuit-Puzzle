import 'package:flutter/material.dart';

import '../theme/volt_theme.dart';

/// Draws one cell as a dark electric panel. Empty cells are a dim socket;
/// powered cells get a dark tinted face, etched traces and a neon rim in
/// [color].
class CircuitPanelPainter extends CustomPainter {
  const CircuitPanelPainter({this.color, this.glow = 1.0});

  /// Null for an empty socket.
  final Color? color;

  /// 0..1 strength of the outer neon glow.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.shortestSide;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.16));
    final c = color;

    if (c == null) {
      canvas.drawRRect(rrect, Paint()..color = VoltColors.panel);
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = VoltColors.panelBorder,
      );
      canvas.drawCircle(
        rect.center,
        w * 0.045,
        Paint()..color = VoltColors.panelBorder,
      );
      return;
    }

    if (glow > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = c.withValues(alpha: 0.5 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, w * 0.14),
      );
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(c, Colors.black, 0.45)!,
            Color.lerp(c, Colors.black, 0.78)!,
          ],
        ).createShader(rect),
    );

    // Etched circuit traces.
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..color = c.withValues(alpha: 0.55);
    final path = Path()
      ..moveTo(w * 0.18, w * 0.32)
      ..lineTo(w * 0.42, w * 0.32)
      ..lineTo(w * 0.58, w * 0.5)
      ..lineTo(w * 0.82, w * 0.5)
      ..moveTo(w * 0.3, w * 0.82)
      ..lineTo(w * 0.3, w * 0.62)
      ..lineTo(w * 0.5, w * 0.62);
    canvas.drawPath(path, trace);
    final pad = Paint()..color = c.withValues(alpha: 0.8);
    for (final p in [
      Offset(w * 0.18, w * 0.32),
      Offset(w * 0.82, w * 0.5),
      Offset(w * 0.5, w * 0.62),
    ]) {
      canvas.drawCircle(p, w * 0.055, pad);
    }

    // Top bevel highlight.
    canvas.drawLine(
      Offset(w * 0.22, w * 0.1),
      Offset(w * 0.78, w * 0.1),
      Paint()
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Neon rim.
    canvas.drawRRect(
      rrect.deflate(w * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = c.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(CircuitPanelPainter old) =>
      old.color != color || old.glow != glow;
}
