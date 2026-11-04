import 'dart:math';

import '../models/models.dart';

/// Produces random tray shapes. Inject a seeded [Random] for deterministic
/// tests.
class ShapeGenerator {
  ShapeGenerator({Random? random, this.specialChance = 0.12})
    : _random = random ?? Random();

  final Random _random;

  /// Probability that a spawned shape carries a battery or multiplier tile.
  final double specialChance;
  int _counter = 0;

  static const List<List<CellOffset>> catalog = [
    [CellOffset(0, 0)], // dot
    [CellOffset(0, 0), CellOffset(0, 1)], // h2
    [CellOffset(0, 0), CellOffset(1, 0)], // v2
    [CellOffset(0, 0), CellOffset(0, 1), CellOffset(0, 2)], // h3
    [CellOffset(0, 0), CellOffset(1, 0), CellOffset(2, 0)], // v3
    [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
    ], // square
    [CellOffset(0, 0), CellOffset(1, 0), CellOffset(1, 1)], // L small
    [CellOffset(0, 1), CellOffset(1, 0), CellOffset(1, 1)], // J small
    [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(2, 1),
    ], // L
    [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 1),
    ], // T
    [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(1, 1),
      CellOffset(1, 2),
    ], // Z
    [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(0, 3),
    ], // h4
  ];

  PuzzleShape next() {
    final cells = catalog[_random.nextInt(catalog.length)];
    var special = SpecialTile.none;
    if (_random.nextDouble() < specialChance) {
      special = _random.nextDouble() < 0.6
          ? SpecialTile.battery
          : SpecialTile.multiplier;
    }
    return PuzzleShape(
      id: 'shape_${_counter++}',
      cells: cells,
      colorId: 1 + _random.nextInt(VoltPalette.shapeColorCount),
      special: special,
      specialIndex: _random.nextInt(cells.length),
    );
  }

  List<PuzzleShape> nextTray([int count = 3]) =>
      List.unmodifiable(List.generate(count, (_) => next()));
}
