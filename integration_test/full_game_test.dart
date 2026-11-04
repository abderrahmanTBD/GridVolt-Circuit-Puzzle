// Plays a complete game through the real UI on a device or emulator:
// tutorial -> drag every piece onto the board -> Game Over -> Replay.
//
//   flutter test integration_test -d <device-id>
//
// WARNING: after the run, Flutter uninstalls the app from the device, which
// deletes its saved data (high score, game in progress). Use an emulator, or
// back up first. Keep the screen on and the app in front while it runs.
//
// Uses a throwaway storage directory during the run, and
// real audio, so the native sound path is exercised too.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/app.dart';
import 'package:grid_volt/application/game/game_bloc.dart';
import 'package:grid_volt/domain/engine/grid_volt_engine.dart';
import 'package:grid_volt/domain/engine/shape_generator.dart';
import 'package:grid_volt/domain/models/models.dart';
import 'package:grid_volt/presentation/effects/sound_effects.dart';
import 'package:grid_volt/presentation/screens/game_screen.dart';
import 'package:grid_volt/presentation/widgets/shape_tray.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Picks the legal move that clears the fewest lines (first in scan order),
/// so the board fills up and the game ends in a bounded number of moves.
(PuzzleShape, int, int)? _chooseMove(GameState s) {
  (PuzzleShape, int, int)? best;
  var bestClears = 1 << 30;
  final n = s.gridMatrix.length;
  for (final shape in s.trayShapes) {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (!GridVoltEngine.canPlaceShape(s.gridMatrix, shape, r, c)) continue;
        final clears = GridVoltEngine.applyMove(
          s.gridMatrix,
          shape,
          r,
          c,
        ).clearedLinesCount;
        if (clears < bestClears) {
          best = (shape, r, c);
          bestClears = clears;
          if (clears == 0) return best;
        }
      }
    }
  }
  return best;
}

/// Drags [shape] from its tray slot so it lands with its origin at (r, c).
Future<void> _dragOntoBoard(
  WidgetTester tester,
  PuzzleShape shape,
  int r,
  int c,
) async {
  final cell = tester.getRect(find.byKey(ValueKey('cell-$r-$c')));
  final from = tester.getCenter(find.byKey(ValueKey(shape.id)));
  final to = cell.center - TrayDragGeometry.feedbackOffset(shape, cell.width);

  final gesture = await tester.startGesture(from);
  await tester.pump();
  for (var i = 1; i <= 6; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 6)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays a full game from tutorial to replay', (tester) async {
    final tmp = await getTemporaryDirectory();
    final storageDir = Directory(
      '${tmp.path}/it_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(storageDir.path),
    );
    final sfx = await AudioPlayersSoundEffects.create();
    addTearDown(() async {
      await sfx.dispose();
      await HydratedBloc.storage.close();
      storageDir.deleteSync(recursive: true);
    });

    final bloc = GameBloc(shapeGenerator: ShapeGenerator(random: Random(7)))
      ..add(const ResumeOrStartGame());
    await tester.pumpWidget(GridVoltApp(soundEffects: sfx, gameBloc: bloc));
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Fresh install: the tutorial appears. Read all three steps.
    expect(find.byKey(const Key('tutorial-overlay')), findsOneWidget);
    for (final label in ['NEXT', 'NEXT', 'PLAY']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);

    // 2. Play until no piece fits, dragging every piece through the UI.
    var moves = 0;
    while (!bloc.state.isGameOver) {
      final move = _chooseMove(bloc.state);
      expect(move, isNotNull, reason: 'not game over, so a move must exist');
      final (shape, r, c) = move!;
      final before = bloc.state;

      await _dragOntoBoard(tester, shape, r, c);

      expect(
        bloc.state.currentScore,
        greaterThan(before.currentScore),
        reason: 'move ${moves + 1}: dropping ${shape.id} at ($r,$c) scored',
      );
      expect(bloc.state.trayShapes.any((s) => s.id == shape.id), isFalse);
      expect(
        bloc.state.trayShapes,
        anyOf(hasLength(before.trayShapes.length - 1), hasLength(3)),
      );
      moves++;
      debugPrint(
        'move $moves: ${shape.id} -> ($r,$c), score ${bloc.state.currentScore}',
      );
      expect(moves, lessThan(150), reason: 'game should end');
    }
    final finalScore = bloc.state.currentScore;
    debugPrint('Game over after $moves moves, score $finalScore');

    // 3. Game Over dialog shows the final score; Replay starts over.
    await tester.pump(GameScreen.gameOverDelay);
    await tester.pumpAndSettle();
    expect(find.text('CIRCUIT OVERLOAD'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('game-over-score'))).data,
      '$finalScore',
    );
    expect(find.text('NEW HIGH SCORE'), findsOneWidget);

    await tester.tap(find.text('REPLAY'));
    await tester.pumpAndSettle();
    expect(find.text('CIRCUIT OVERLOAD'), findsNothing);
    expect(bloc.state.currentScore, 0);
    expect(bloc.state.highScore, finalScore);
    expect(bloc.state.trayShapes, hasLength(3));
    expect(bloc.state.isGameOver, isFalse);
  });
}
