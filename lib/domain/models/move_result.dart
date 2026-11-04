import 'package:equatable/equatable.dart';

import 'cell_offset.dart';
import 'grid_cell.dart';
import 'puzzle_shape.dart';

/// A board cell that was cleared by a move, with what it held just before.
class ClearedCell extends Equatable {
  const ClearedCell(this.position, this.cell, {required this.bySurge});

  final CellOffset position;
  final GridCell cell;

  /// True if removed by a battery explosion rather than a completed line.
  final bool bySurge;

  @override
  List<Object?> get props => [position, cell, bySurge];
}

/// Outcome of a single placement, consumed by the UI for animations and SFX.
class MoveResult extends Equatable {
  const MoveResult({
    required this.grid,
    required this.shape,
    required this.originRow,
    required this.originCol,
    required this.clearedRows,
    required this.clearedCols,
    required this.clearedCells,
    required this.surgeOrigins,
    required this.multiplier,
    required this.pointsEarned,
  });

  final List<List<GridCell>> grid;
  final PuzzleShape shape;
  final int originRow;
  final int originCol;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<ClearedCell> clearedCells;

  /// Board positions of every battery that exploded, in chain order.
  final List<CellOffset> surgeOrigins;
  final int multiplier;
  final int pointsEarned;

  int get clearedLinesCount => clearedRows.length + clearedCols.length;
  int get batterySurgeCount => surgeOrigins.length;

  @override
  List<Object?> get props => [
    grid,
    shape,
    originRow,
    originCol,
    clearedRows,
    clearedCols,
    clearedCells,
    surgeOrigins,
    multiplier,
    pointsEarned,
  ];
}
