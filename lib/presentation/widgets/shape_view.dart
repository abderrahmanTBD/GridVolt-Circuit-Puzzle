import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import 'volt_cell.dart';

/// Renders a [PuzzleShape] at [cellSize] per cell, using the same per-cell
/// inset as the board so a dragged shape lines up exactly with the grid.
class ShapeView extends StatelessWidget {
  const ShapeView({
    super.key,
    required this.shape,
    required this.cellSize,
    this.glow = 1.0,
  });

  final PuzzleShape shape;
  final double cellSize;
  final double glow;

  static double cellInset(double cellSize) => cellSize * 0.05;

  @override
  Widget build(BuildContext context) {
    final inset = cellInset(cellSize);
    return SizedBox(
      width: shape.colCount * cellSize,
      height: shape.rowCount * cellSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shape.cells.length; i++)
            Positioned(
              left: shape.cells[i].col * cellSize + inset,
              top: shape.cells[i].row * cellSize + inset,
              child: VoltCell(
                cell: shape.cellAt(i),
                size: cellSize - 2 * inset,
                glow: glow,
              ),
            ),
        ],
      ),
    );
  }
}
