import 'package:flutter/material.dart';

import '../theme/volt_theme.dart';
import '../widgets/placement_preview.dart';

/// Semi-transparent ghost of the dragged shape under the touch target:
/// tinted in the shape color when it fits (with the lines it would clear
/// highlighted), red when it doesn't.
class PlacementPreviewPainter extends CustomPainter {
  const PlacementPreviewPainter({
    required this.preview,
    required this.cellSize,
  });

  final PlacementPreview? preview;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final p = preview;
    if (p == null) return;
    final color = p.isValid ? Color(p.shape.colorHex) : VoltColors.danger;

    if (p.isValid) {
      final band = Paint()..color = color.withValues(alpha: 0.13);
      for (final r in p.clearRows) {
        canvas.drawRect(
          Rect.fromLTWH(0, r * cellSize, size.width, cellSize),
          band,
        );
      }
      for (final c in p.clearCols) {
        canvas.drawRect(
          Rect.fromLTWH(c * cellSize, 0, cellSize, size.height),
          band,
        );
      }
    }

    final inset = cellSize * 0.06;
    final fill = Paint()..color = color.withValues(alpha: 0.32);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.05
      ..color = color.withValues(alpha: 0.85);
    for (final cell in p.cells) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cell.col * cellSize + inset,
          cell.row * cellSize + inset,
          cellSize - 2 * inset,
          cellSize - 2 * inset,
        ),
        Radius.circular(cellSize * 0.16),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, rim);
    }
  }

  @override
  bool shouldRepaint(PlacementPreviewPainter old) =>
      old.preview != preview || old.cellSize != cellSize;
}
