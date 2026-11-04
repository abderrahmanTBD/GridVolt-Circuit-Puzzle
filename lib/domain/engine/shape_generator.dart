import 'dart:math';

import '../models/models.dart';
import 'grid_volt_engine.dart';

/// Produces tray shapes. Inject a seeded [Random] for deterministic tests.
///
/// Dealing is random but fair when given the board:
///  * the fuller the board, the more small pieces are favoured;
///  * at least one dealt piece always fits somewhere, so a game ends because
///    of how it was played, not because of an unlucky deal.
class ShapeGenerator {
  ShapeGenerator({
    Random? random,
    this.specialChance = 0.12,
    this.sizeBias = 0.8,
  }) : _random = random ?? Random() {
    // Ids must not collide with shapes restored from a previous session.
    _idPrefix = _random.nextInt(1 << 30).toRadixString(36);
  }

  final Random _random;
  late final String _idPrefix;

  /// Probability that a spawned shape carries a battery or multiplier tile.
  final double specialChance;

  /// How strongly a full board favours small pieces (0 = uniform).
  final double sizeBias;
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

  /// A random shape. [fill] (0..1, share of occupied cells) biases the pick
  /// towards smaller pieces.
  PuzzleShape next({double fill = 0}) => _build(_pick(catalog, fill));

  /// Deals [count] shapes. With a [grid], applies the fairness rules above.
  List<PuzzleShape> nextTray({GridMatrix? grid, int count = 3}) {
    if (grid == null) {
      return List.unmodifiable(List.generate(count, (_) => next()));
    }
    final total = grid.length * grid.length;
    final filled = grid.fold<int>(
      0,
      (n, row) => n + row.where((c) => c.isFilled).length,
    );
    final fill = total == 0 ? 0.0 : filled / total;
    final tray = List.generate(count, (_) => next(fill: fill));

    if (!GridVoltEngine.hasValidMoves(grid, tray)) {
      final fitting = [
        for (final cells in catalog)
          if (GridVoltEngine.hasValidMoves(grid, [_probe(cells)])) cells,
      ];
      if (fitting.isNotEmpty) {
        tray[_random.nextInt(count)] = _build(_pick(fitting, fill));
      }
    }
    return List.unmodifiable(tray);
  }

  static PuzzleShape _probe(List<CellOffset> cells) =>
      PuzzleShape(id: 'probe', cells: cells, colorId: 1);

  /// Weighted pick: weight = e^(-sizeBias · fill · (cells - 1)).
  List<CellOffset> _pick(List<List<CellOffset>> options, double fill) {
    final weights = [
      for (final o in options) exp(-sizeBias * fill * (o.length - 1)),
    ];
    var r = _random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < options.length; i++) {
      r -= weights[i];
      if (r <= 0) return options[i];
    }
    return options.last;
  }

  PuzzleShape _build(List<CellOffset> cells) {
    var special = SpecialTile.none;
    if (_random.nextDouble() < specialChance) {
      special = _random.nextDouble() < 0.6
          ? SpecialTile.battery
          : SpecialTile.multiplier;
    }
    return PuzzleShape(
      id: 'shape_${_idPrefix}_${_counter++}',
      cells: cells,
      colorId: 1 + _random.nextInt(VoltPalette.shapeColorCount),
      special: special,
      specialIndex: _random.nextInt(cells.length),
    );
  }
}
