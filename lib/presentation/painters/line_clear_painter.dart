import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/volt_theme.dart';

/// Line-clear effect for a [MoveResult]: energy beams sweep the cleared
/// rows/columns while each cleared panel flashes white, swells and fades.
/// Battery surges add expanding shock rings, staggered along the chain.
class LineClearPainter extends CustomPainter {
  const LineClearPainter({
    required this.result,
    required this.progress,
    required this.cellSize,
  });

  final MoveResult result;

  /// 0..1 animation progress.
  final double progress;
  final double cellSize;

  static double _local(double t, double delay, [double span = 1]) =>
      ((t - delay) / (span - delay)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    if (t >= 1) return;

    // Beams.
    final beamT = Curves.easeOut.transform(_local(t, 0, 0.6));
    if (beamT < 1) {
      final thickness = cellSize * (0.9 - 0.8 * beamT);
      final beam = Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * (1 - beamT))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.25);
      for (final r in result.clearedRows) {
        final cy = (r + 0.5) * cellSize;
        canvas.drawRect(
          Rect.fromLTWH(0, cy - thickness / 2, size.width, thickness),
          beam,
        );
      }
      for (final c in result.clearedCols) {
        final cx = (c + 0.5) * cellSize;
        canvas.drawRect(
          Rect.fromLTWH(cx - thickness / 2, 0, thickness, size.height),
          beam,
        );
      }
    }

    // Flash + scale of every cleared panel.
    for (final cleared in result.clearedCells) {
      final lt = Curves.easeOutCubic.transform(
        _local(t, cleared.bySurge ? 0.18 : 0.0, 0.85),
      );
      if (lt >= 1) continue;
      final base = Color(cleared.cell.colorHex);
      final color = Color.lerp(Colors.white, base, lt)!;
      final s = cellSize * (0.9 + 0.4 * lt);
      final center = Offset(
        (cleared.position.col + 0.5) * cellSize,
        (cleared.position.row + 0.5) * cellSize,
      );
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: s, height: s),
        Radius.circular(s * 0.18),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: 0.5 * (1 - lt))
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, cellSize * 0.2),
      );
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 1 - lt));
    }

    // Battery surge shock rings.
    for (var i = 0; i < result.surgeOrigins.length; i++) {
      final o = result.surgeOrigins[i];
      final lt = Curves.easeOut.transform(_local(t, min(0.5, 0.08 * i)));
      if (lt >= 1) continue;
      final center = Offset((o.col + 0.5) * cellSize, (o.row + 0.5) * cellSize);
      canvas.drawCircle(
        center,
        cellSize * (0.4 + 1.4 * lt),
        Paint()
          ..color = VoltColors.volt.withValues(alpha: 0.45 * (1 - lt))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.3),
      );
      canvas.drawCircle(
        center,
        cellSize * (0.5 + 1.9 * lt),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.22 * (1 - lt) + 1
          ..color = Color.lerp(
            Colors.white,
            VoltColors.volt,
            lt,
          )!.withValues(alpha: 1 - lt),
      );
    }
  }

  @override
  bool shouldRepaint(LineClearPainter old) =>
      old.progress != progress ||
      old.result != result ||
      old.cellSize != cellSize;
}
