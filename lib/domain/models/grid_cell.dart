import 'package:equatable/equatable.dart';

import 'special_tile.dart';
import 'volt_palette.dart';

/// One board cell. [colorId] 0 means empty.
class GridCell extends Equatable {
  const GridCell({this.colorId = 0, this.special = SpecialTile.none});

  static const empty = GridCell();

  final int colorId;
  final SpecialTile special;

  bool get isEmpty => colorId == 0;
  bool get isFilled => colorId != 0;
  int get colorHex => VoltPalette.colorHex(colorId);

  @override
  List<Object?> get props => [colorId, special];
}
