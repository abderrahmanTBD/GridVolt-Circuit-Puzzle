import 'package:equatable/equatable.dart';

/// A (row, col) pair. Used both as an offset inside a shape's bounding box and
/// as an absolute board coordinate.
class CellOffset extends Equatable {
  const CellOffset(this.row, this.col);

  final int row;
  final int col;

  CellOffset operator +(CellOffset other) =>
      CellOffset(row + other.row, col + other.col);

  @override
  List<Object?> get props => [row, col];
}
