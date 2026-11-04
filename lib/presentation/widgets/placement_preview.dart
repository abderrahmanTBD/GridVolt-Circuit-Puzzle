import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../domain/engine/grid_volt_engine.dart';
import '../../domain/models/models.dart';

/// What the board should show while a shape hovers over cell ([row], [col]).
class PlacementPreview extends Equatable {
  const PlacementPreview({
    required this.shape,
    required this.row,
    required this.col,
    required this.isValid,
    required this.cells,
    this.clearRows = const [],
    this.clearCols = const [],
  });

  factory PlacementPreview.compute(
    GridMatrix grid,
    PuzzleShape shape,
    int row,
    int col,
  ) {
    final size = grid.length;
    final isValid = GridVoltEngine.canPlaceShape(grid, shape, row, col);
    final cells = [
      for (final c in shape.cells)
        if (row + c.row >= 0 &&
            row + c.row < size &&
            col + c.col >= 0 &&
            col + c.col < size)
          CellOffset(row + c.row, col + c.col),
    ];
    if (!isValid) {
      return PlacementPreview(
        shape: shape,
        row: row,
        col: col,
        isValid: false,
        cells: cells,
      );
    }
    final result = GridVoltEngine.applyMove(grid, shape, row, col);
    return PlacementPreview(
      shape: shape,
      row: row,
      col: col,
      isValid: true,
      cells: cells,
      clearRows: result.clearedRows,
      clearCols: result.clearedCols,
    );
  }

  final PuzzleShape shape;
  final int row;
  final int col;
  final bool isValid;

  /// In-bounds absolute board cells the shape would cover.
  final List<CellOffset> cells;
  final List<int> clearRows;
  final List<int> clearCols;

  bool isAt(int r, int c) => row == r && col == c;

  @override
  List<Object?> get props => [
    shape.id,
    row,
    col,
    isValid,
    cells,
    clearRows,
    clearCols,
  ];
}

/// Shared between board cells (which write it) and the preview overlay.
typedef PlacementPreviewController = ValueNotifier<PlacementPreview?>;
