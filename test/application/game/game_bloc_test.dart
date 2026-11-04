import 'dart:convert';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/application/game/game_bloc.dart';
import 'package:grid_volt/domain/engine/grid_volt_engine.dart';
import 'package:grid_volt/domain/engine/shape_generator.dart';
import 'package:grid_volt/domain/models/models.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers.dart';

GameState _seeded({
  GridMatrix? grid,
  List<PuzzleShape> tray = const [dot, h2, square],
  int score = 0,
  int highScore = 0,
}) => GameState(
  gridMatrix: grid ?? GridVoltEngine.emptyGrid(),
  trayShapes: tray,
  currentScore: score,
  highScore: highScore,
  highScoreAtStart: highScore,
  isGameOver: false,
);

void main() {
  late MockStorage storage;

  setUp(() => storage = installMockStorage());

  GameBloc buildBloc() =>
      GameBloc(shapeGenerator: ShapeGenerator(random: Random(42)));

  group('StartNewGame', () {
    blocTest<GameBloc, GameState>(
      'deals 3 shapes, resets score and grid, keeps high score',
      build: buildBloc,
      seed: () => _seeded(grid: almostFullRow0(), score: 40, highScore: 99),
      act: (bloc) => bloc.add(const StartNewGame()),
      expect: () => [
        isA<GameState>()
            .having((s) => s.trayShapes.length, 'tray', 3)
            .having((s) => s.currentScore, 'score', 0)
            .having((s) => s.highScore, 'highScore', 99)
            .having((s) => s.highScoreAtStart, 'highScoreAtStart', 99)
            .having((s) => s.isGameOver, 'isGameOver', false)
            .having((s) => s.lastMoveResult, 'lastMoveResult', isNull)
            .having(
              (s) => s.gridMatrix.every((r) => r.every((v) => v.isEmpty)),
              'grid empty',
              true,
            ),
      ],
    );
  });

  group('PlaceShape', () {
    blocTest<GameBloc, GameState>(
      'removes the shape from the tray and adds its cell count to the score',
      build: buildBloc,
      seed: () => _seeded(),
      act: (bloc) => bloc.add(const PlaceShape(square, 3, 3)),
      expect: () => [
        isA<GameState>()
            .having((s) => s.trayShapes.length, 'tray count', 2)
            .having((s) => s.trayShapes, 'tray', [dot, h2])
            .having((s) => s.currentScore, 'score', 4)
            .having((s) => s.highScore, 'highScore', 4)
            .having((s) => s.gridMatrix[3][3].colorId, 'cell 3,3', 3)
            .having((s) => s.gridMatrix[4][4].colorId, 'cell 4,4', 3)
            .having((s) => s.lastMoveResult?.shape, 'last shape', square),
      ],
    );

    blocTest<GameBloc, GameState>(
      'awards line bonus and clears the completed row',
      build: buildBloc,
      seed: () => _seeded(grid: almostFullRow0(), score: 10),
      act: (bloc) => bloc.add(const PlaceShape(dot, 0, 7)),
      expect: () => [
        isA<GameState>()
            .having((s) => s.trayShapes.length, 'tray count', 2)
            // 10 existing + 1 cell + 10 * 1 line²
            .having((s) => s.currentScore, 'score', 21)
            .having(
              (s) => s.gridMatrix[0].every((v) => v.isEmpty),
              'row cleared',
              true,
            )
            .having((s) => s.lastMoveResult?.clearedRows, 'clearedRows', [0])
            .having(
              (s) => s.lastMoveResult?.clearedLinesCount,
              'clearedLinesCount',
              1,
            ),
      ],
    );

    blocTest<GameBloc, GameState>(
      'does not lower an existing high score',
      build: buildBloc,
      seed: () => _seeded(highScore: 500),
      act: (bloc) => bloc.add(const PlaceShape(dot, 0, 0)),
      expect: () => [
        isA<GameState>()
            .having((s) => s.currentScore, 'score', 1)
            .having((s) => s.highScore, 'highScore', 500)
            .having((s) => s.isNewHighScore, 'isNewHighScore', false),
      ],
    );

    blocTest<GameBloc, GameState>(
      'marks a new high score once the previous best is beaten',
      build: buildBloc,
      seed: () => _seeded(highScore: 3),
      act: (bloc) => bloc.add(const PlaceShape(square, 0, 0)),
      expect: () => [
        isA<GameState>()
            .having((s) => s.highScore, 'highScore', 4)
            .having((s) => s.isNewHighScore, 'isNewHighScore', true),
      ],
    );

    blocTest<GameBloc, GameState>(
      'ignores an out-of-bounds placement',
      build: buildBloc,
      seed: () => _seeded(),
      act: (bloc) => bloc.add(const PlaceShape(square, 7, 7)),
      expect: () => <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'ignores an overlapping placement',
      build: buildBloc,
      seed: () => _seeded(grid: almostFullRow0()),
      act: (bloc) => bloc.add(const PlaceShape(h2, 0, 0)),
      expect: () => <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'ignores a shape that is not in the tray',
      build: buildBloc,
      seed: () => _seeded(tray: const [dot]),
      act: (bloc) => bloc.add(const PlaceShape(square, 0, 0)),
      expect: () => <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'flags game over when no remaining tray shape fits',
      build: buildBloc,
      seed: () {
        // Full board with holes on the diagonal plus (0,0)-(0,1) for the h2,
        // and (0,7)/(7,0) so filling (0,0)-(0,1) completes no row or column.
        // Afterwards no 2x2 empty block exists, so the square cannot fit.
        final g = List.generate(8, (_) => List<GridCell>.filled(8, filled));
        for (var i = 1; i < 8; i++) {
          g[i][i] = GridCell.empty;
        }
        g[0][0] = GridCell.empty;
        g[0][1] = GridCell.empty;
        g[0][7] = GridCell.empty;
        g[7][0] = GridCell.empty;
        return _seeded(grid: g, tray: const [h2, square]);
      },
      act: (bloc) => bloc.add(const PlaceShape(h2, 0, 0)),
      expect: () => [
        isA<GameState>()
            .having((s) => s.trayShapes, 'tray', [square])
            .having((s) => s.isGameOver, 'isGameOver', true),
      ],
    );
  });

  group('ReplenishTrayIfNeeded', () {
    blocTest<GameBloc, GameState>(
      'placing the last tray shape deals 3 new ones',
      build: buildBloc,
      seed: () => _seeded(tray: const [dot]),
      act: (bloc) => bloc.add(const PlaceShape(dot, 0, 0)),
      expect: () => [
        isA<GameState>().having((s) => s.trayShapes.length, 'tray', 0),
        isA<GameState>()
            .having((s) => s.trayShapes.length, 'tray', 3)
            .having((s) => s.currentScore, 'score', 1)
            .having((s) => s.isGameOver, 'isGameOver', false),
      ],
    );

    blocTest<GameBloc, GameState>(
      'does nothing while shapes remain in the tray',
      build: buildBloc,
      seed: () => _seeded(tray: const [dot, h2]),
      act: (bloc) => bloc.add(const ReplenishTrayIfNeeded()),
      expect: () => <GameState>[],
    );
  });

  group('persistence', () {
    test('restores high score from storage on startup', () {
      when(() => storage.read(any())).thenReturn({'highScore': 1234});
      final bloc = buildBloc();
      expect(bloc.state.highScore, 1234);
      expect(bloc.state.highScoreAtStart, 1234);
      expect(bloc.state.currentScore, 0);
      bloc.close();
    });

    test('a finished game stores only the high score', () {
      final over = _seeded(score: 30, highScore: 77).copyWith(isGameOver: true);
      expect(GameStateCodec.encode(over), {'v': 2, 'highScore': 77});
    });

    test('a run in progress round-trips through JSON', () {
      final grid = almostFullRow0();
      grid[5][5] = const GridCell(colorId: 2, special: SpecialTile.battery);
      const special = PuzzleShape(
        id: 'x',
        cells: [CellOffset(0, 0), CellOffset(1, 0)],
        colorId: 6,
        special: SpecialTile.multiplier,
        specialIndex: 1,
      );
      final original = _seeded(
        grid: grid,
        tray: const [dot, special],
        score: 42,
        highScore: 90,
      );

      // Through a real JSON string, as hydrated_bloc stores it.
      final json =
          jsonDecode(jsonEncode(GameStateCodec.encode(original)))
              as Map<String, dynamic>;
      final restored = GameStateCodec.decode(json);

      expect(restored, original);
    });

    test('restores a saved run on startup', () {
      final saved = _seeded(score: 12, highScore: 50, tray: const [h2]);
      when(() => storage.read(any())).thenReturn(GameStateCodec.encode(saved));
      final bloc = buildBloc();
      expect(bloc.state.currentScore, 12);
      expect(bloc.state.trayShapes, [h2]);
      bloc.close();
    });

    test('corrupt save data falls back to a new game keeping the best', () {
      final restored = GameStateCodec.decode({
        'v': 2,
        'highScore': 300,
        'run': {'score': 'oops', 'grid': [], 'tray': 7},
      });
      expect(restored, GameState.initial(highScore: 300));
    });

    test('reads the old high-score-only format', () {
      expect(
        GameStateCodec.decode({'highScore': 55}),
        GameState.initial(highScore: 55),
      );
    });

    blocTest<GameBloc, GameState>(
      'writes the new high score to storage when beaten',
      build: buildBloc,
      seed: () => _seeded(highScore: 2),
      act: (bloc) => bloc.add(const PlaceShape(square, 0, 0)),
      verify: (_) => verify(
        () => storage.write(any(), any(that: containsPair('highScore', 4))),
      ).called(1),
    );
  });

  group('ResumeOrStartGame', () {
    blocTest<GameBloc, GameState>(
      'keeps a restored run untouched',
      build: buildBloc,
      seed: () => _seeded(grid: almostFullRow0(), score: 8),
      act: (bloc) => bloc.add(const ResumeOrStartGame()),
      expect: () => <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'starts a new game when there is nothing to resume',
      build: buildBloc,
      act: (bloc) => bloc.add(const ResumeOrStartGame()),
      expect: () => [
        isA<GameState>().having((s) => s.trayShapes.length, 'tray', 3),
      ],
    );

    blocTest<GameBloc, GameState>(
      'deals a tray for a run saved between placing and dealing',
      build: buildBloc,
      seed: () => _seeded(grid: almostFullRow0(), score: 8, tray: const []),
      act: (bloc) => bloc.add(const ResumeOrStartGame()),
      expect: () => [
        isA<GameState>()
            .having((s) => s.trayShapes.length, 'tray', 3)
            .having((s) => s.currentScore, 'score', 8),
      ],
    );
  });
}
