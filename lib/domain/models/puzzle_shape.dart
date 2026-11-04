import 'dart:math';

import 'package:equatable/equatable.dart';

import 'cell_offset.dart';
import 'grid_cell.dart';
import 'special_tile.dart';
import 'volt_palette.dart';

/// A placeable piece. [id] is unique per spawned instance so two identical
/// shapes in the tray can still be told apart. At most one cell (at
/// [specialIndex]) carries a [special] tile.
class PuzzleShape extends Equatable {
  const PuzzleShape({
    required this.id,
    required this.cells,
    required this.colorId,
    this.special = SpecialTile.none,
    this.specialIndex = 0,
  }) : assert(colorId > 0, 'colorId 0 is reserved for empty cells');

  final String id;
  final List<CellOffset> cells;
  final int colorId;
  final SpecialTile special;
  final int specialIndex;

  int get colorHex => VoltPalette.colorHex(colorId);
  int get rowCount => cells.map((c) => c.row).reduce(max) + 1;
  int get colCount => cells.map((c) => c.col).reduce(max) + 1;

  /// The board cell this shape writes at its [index]th offset.
  GridCell cellAt(int index) => GridCell(
    colorId: colorId,
    special: index == specialIndex ? special : SpecialTile.none,
  );

  @override
  List<Object?> get props => [id, cells, colorId, special, specialIndex];
}
