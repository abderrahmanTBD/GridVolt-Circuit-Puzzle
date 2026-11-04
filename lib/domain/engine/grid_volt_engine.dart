import 'dart:math';

import '../models/models.dart';

/// Rows of [GridCell]s, indexed `[row][col]`.
typedef GridMatrix = List<List<GridCell>>;

/// Pure, stateless rules of GridVolt. No Flutter imports.
///
/// Scoring per move:
///  * 1 point per placed cell
///  * 10 × lines² for completed rows/columns (combo bonus)
///  * 25 per battery surge + 3 per extra cell the blast removes
///  * the total is doubled for each multiplier tile cleared (max ×8)
abstract final class GridVoltEngine {
  static const int defaultSize = 8;
  static const int pointsPerCell = 1;
  static const int pointsPerLine = 10;
  static const int pointsPerSurge = 25;
  static const int pointsPerSurgeCell = 3;
  static const int maxMultiplier = 8;

  static GridMatrix emptyGrid([int size = defaultSize]) => List.unmodifiable(
    List.generate(size, (_) => List<GridCell>.filled(size, GridCell.empty)),
  );

  static bool canPlaceShape(
    GridMatrix grid,
    PuzzleShape shape,
    int originRow,
    int originCol,
  ) {
    final size = grid.length;
    for (final c in shape.cells) {
      final r = originRow + c.row;
      final col = originCol + c.col;
      if (r < 0 || r >= size || col < 0 || col >= size) return false;
      if (grid[r][col].isFilled) return false;
    }
    return true;
  }

  /// Places [shape], clears completed lines and resolves battery surges.
  /// Throws [ArgumentError] if the move is illegal — call [canPlaceShape]
  /// first.
  static MoveResult applyMove(
    GridMatrix grid,
    PuzzleShape shape,
    int originRow,
    int originCol,
  ) {
    if (!canPlaceShape(grid, shape, originRow, originCol)) {
      throw ArgumentError('Illegal placement at ($originRow, $originCol)');
    }
    final size = grid.length;
    final next = [for (final row in grid) List<GridCell>.of(row)];

    for (var i = 0; i < shape.cells.length; i++) {
      final c = shape.cells[i];
      next[originRow + c.row][originCol + c.col] = shape.cellAt(i);
    }

    final fullRows = [
      for (var r = 0; r < size; r++)
        if (next[r].every((v) => v.isFilled)) r,
    ];
    final fullCols = [
      for (var c = 0; c < size; c++)
        if (next.every((row) => row[c].isFilled)) c,
    ];

    // position -> cleared-by-surge flag, insertion ordered.
    final cleared = <CellOffset, bool>{};
    for (final r in fullRows) {
      for (var c = 0; c < size; c++) {
        cleared[CellOffset(r, c)] = false;
      }
    }
    for (final c in fullCols) {
      for (var r = 0; r < size; r++) {
        cleared[CellOffset(r, c)] = false;
      }
    }

    // Battery chain reaction (BFS over batteries caught in a clear).
    final surgeOrigins = <CellOffset>[];
    final queue = [
      for (final p in cleared.keys)
        if (next[p.row][p.col].special == SpecialTile.battery) p,
    ];
    final exploded = <CellOffset>{};
    while (queue.isNotEmpty) {
      final b = queue.removeAt(0);
      if (!exploded.add(b)) continue;
      surgeOrigins.add(b);
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final p = CellOffset(b.row + dr, b.col + dc);
          if (p.row < 0 || p.row >= size || p.col < 0 || p.col >= size) {
            continue;
          }
          if (next[p.row][p.col].isEmpty || cleared.containsKey(p)) continue;
          cleared[p] = true;
          if (next[p.row][p.col].special == SpecialTile.battery) queue.add(p);
        }
      }
    }

    final clearedCells = [
      for (final e in cleared.entries)
        ClearedCell(e.key, next[e.key.row][e.key.col], bySurge: e.value),
    ];
    final multiplierTiles = clearedCells
        .where((c) => c.cell.special == SpecialTile.multiplier)
        .length;
    final multiplier = min(maxMultiplier, 1 << multiplierTiles);

    for (final p in cleared.keys) {
      next[p.row][p.col] = GridCell.empty;
    }

    final lines = fullRows.length + fullCols.length;
    final surgeCells = clearedCells.where((c) => c.bySurge).length;
    final base =
        shape.cells.length * pointsPerCell +
        pointsPerLine * lines * lines +
        pointsPerSurge * surgeOrigins.length +
        pointsPerSurgeCell * surgeCells;

    return MoveResult(
      grid: List.unmodifiable(next.map(List<GridCell>.unmodifiable)),
      shape: shape,
      originRow: originRow,
      originCol: originCol,
      clearedRows: List.unmodifiable(fullRows),
      clearedCols: List.unmodifiable(fullCols),
      clearedCells: List.unmodifiable(clearedCells),
      surgeOrigins: List.unmodifiable(surgeOrigins),
      multiplier: multiplier,
      pointsEarned: base * multiplier,
    );
  }

  /// True if at least one of [shapes] fits somewhere on [grid].
  static bool hasValidMoves(GridMatrix grid, List<PuzzleShape> shapes) {
    final size = grid.length;
    for (final shape in shapes) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (canPlaceShape(grid, shape, r, c)) return true;
        }
      }
    }
    return false;
  }
}
