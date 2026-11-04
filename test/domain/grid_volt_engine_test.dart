import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/domain/engine/grid_volt_engine.dart';
import 'package:grid_volt/domain/engine/shape_generator.dart';
import 'package:grid_volt/domain/models/models.dart';

import '../helpers.dart';

void main() {
  _fairDealingTests();

  group('canPlaceShape', () {
    test('rejects out of bounds and overlaps', () {
      final g = almostFullRow0();
      expect(GridVoltEngine.canPlaceShape(g, square, 6, 6), isTrue);
      expect(GridVoltEngine.canPlaceShape(g, square, 7, 6), isFalse);
      expect(GridVoltEngine.canPlaceShape(g, square, -1, 0), isFalse);
      expect(GridVoltEngine.canPlaceShape(g, dot, 0, 3), isFalse);
      expect(GridVoltEngine.canPlaceShape(g, dot, 0, 7), isTrue);
    });
  });

  group('applyMove', () {
    test('clears a row and a column together with a combo bonus', () {
      final g = mutableGrid();
      for (var i = 1; i < 8; i++) {
        g[0][i] = filled; // row 0 missing (0,0)
        g[i][0] = filled; // col 0 missing (0,0)
      }
      final r = GridVoltEngine.applyMove(g, dot, 0, 0);
      expect(r.clearedRows, [0]);
      expect(r.clearedCols, [0]);
      expect(r.clearedLinesCount, 2);
      expect(r.clearedCells.length, 15);
      expect(r.pointsEarned, 1 + 10 * 4);
      expect(r.grid.every((row) => row.every((c) => c.isEmpty)), isTrue);
    });

    test('battery in a cleared line explodes its 3x3 neighbourhood', () {
      final g = almostFullRow0();
      g[0][3] = const GridCell(colorId: 5, special: SpecialTile.battery);
      g[1][2] = filled;
      g[1][4] = filled;
      g[2][3] = filled; // outside the blast radius
      final r = GridVoltEngine.applyMove(g, dot, 0, 7);

      expect(r.surgeOrigins, [const CellOffset(0, 3)]);
      expect(r.grid[1][2].isEmpty, isTrue);
      expect(r.grid[1][4].isEmpty, isTrue);
      expect(r.grid[2][3].isFilled, isTrue);
      expect(r.clearedCells.where((c) => c.bySurge).length, 2);
      // 1 cell + 10 line + 25 surge + 2 * 3 blast cells
      expect(r.pointsEarned, 1 + 10 + 25 + 6);
    });

    test('battery surges chain into other batteries', () {
      final g = almostFullRow0();
      g[0][0] = const GridCell(colorId: 5, special: SpecialTile.battery);
      g[1][1] = const GridCell(colorId: 5, special: SpecialTile.battery);
      g[2][2] = filled;
      final r = GridVoltEngine.applyMove(g, dot, 0, 7);
      expect(r.surgeOrigins, [const CellOffset(0, 0), const CellOffset(1, 1)]);
      expect(r.grid[2][2].isEmpty, isTrue);
    });

    test('cleared multiplier tile doubles the move score', () {
      final g = almostFullRow0();
      g[0][2] = const GridCell(colorId: 5, special: SpecialTile.multiplier);
      final r = GridVoltEngine.applyMove(g, dot, 0, 7);
      expect(r.multiplier, 2);
      expect(r.pointsEarned, (1 + 10) * 2);
    });

    test('placed special tiles land on the board', () {
      const shape = PuzzleShape(
        id: 'b',
        cells: [CellOffset(0, 0), CellOffset(0, 1)],
        colorId: 1,
        special: SpecialTile.battery,
        specialIndex: 1,
      );
      final r = GridVoltEngine.applyMove(
        GridVoltEngine.emptyGrid(),
        shape,
        4,
        4,
      );
      expect(r.grid[4][4].special, SpecialTile.none);
      expect(r.grid[4][5].special, SpecialTile.battery);
    });

    test('throws on an illegal move', () {
      expect(
        () =>
            GridVoltEngine.applyMove(GridVoltEngine.emptyGrid(), square, 7, 7),
        throwsArgumentError,
      );
    });
  });

  test(
    'ShapeGenerator is deterministic for a given seed and ids are unique',
    () {
      final a = ShapeGenerator(random: Random(1)).nextTray();
      final b = ShapeGenerator(random: Random(1)).nextTray();
      expect(a, b);
      expect(a.map((s) => s.id).toSet().length, 3);
    },
  );
}

/// Board with only isolated single-cell holes: nothing but a dot fits.
List<List<GridCell>> _checkerHoles() {
  final g = mutableGrid();
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      g[r][c] = (r.isEven && c.isEven) ? GridCell.empty : filled;
    }
  }
  return g;
}

int _filled(List<List<GridCell>> g) =>
    g.fold(0, (n, row) => n + row.where((c) => c.isFilled).length);

void _fairDealingTests() {
  group('fair dealing', () {
    test('always deals at least one piece that fits', () {
      final grid = _checkerHoles();
      for (var seed = 0; seed < 200; seed++) {
        final tray = ShapeGenerator(random: Random(seed)).nextTray(grid: grid);
        expect(tray, hasLength(3));
        expect(
          GridVoltEngine.hasValidMoves(grid, tray),
          isTrue,
          reason: 'seed $seed dealt an unplayable tray',
        );
      }
    });

    test('a fuller board deals smaller pieces on average', () {
      double avgSize(List<List<GridCell>> grid) {
        final gen = ShapeGenerator(random: Random(3));
        var cells = 0, n = 0;
        for (var i = 0; i < 400; i++) {
          for (final s in gen.nextTray(grid: grid)) {
            cells += s.cells.length;
            n++;
          }
        }
        return cells / n;
      }

      final crowded = mutableGrid();
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 7; c++) {
          crowded[r][c] = filled; // ~66% full, no complete lines
        }
      }
      expect(_filled(crowded), 42);

      final emptyAvg = avgSize(GridVoltEngine.emptyGrid());
      final crowdedAvg = avgSize(crowded);
      expect(crowdedAvg, lessThan(emptyAvg - 0.4));
    });

    test('ids from separate generators do not collide', () {
      final a = ShapeGenerator(random: Random(1)).nextTray();
      final b = ShapeGenerator(random: Random(2)).nextTray();
      expect(
        a.map((s) => s.id).toSet().intersection(b.map((s) => s.id).toSet()),
        isEmpty,
      );
    });
  });
}
