import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/app.dart';
import 'package:grid_volt/application/game/game_bloc.dart';
import 'package:grid_volt/domain/engine/shape_generator.dart';
import 'package:grid_volt/presentation/effects/sound_effects.dart';
import 'package:grid_volt/presentation/painters/placement_preview_painter.dart';
import 'package:grid_volt/presentation/screens/game_screen.dart';
import 'package:grid_volt/presentation/widgets/shape_tray.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class MockGameBloc extends MockBloc<GameEvent, GameState> implements GameBloc {}

class RecordingSoundEffects implements SoundEffects {
  final played = <Sfx>[];

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  Future<void> dispose() async {}
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

GameBloc _seededBloc() => GameBloc(
  shapeGenerator: ShapeGenerator(random: Random(42), specialChance: 0),
)..add(const StartNewGame());

Finder _validPreview() => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter is PlacementPreviewPainter &&
      (w.painter! as PlacementPreviewPainter).preview?.isValid == true,
);

void main() {
  setUp(installMockStorage);

  group('responsive layout renders without overflow', () {
    const sizes = {
      'small phone': Size(320, 568),
      'modern phone': Size(390, 844),
      'tall phone': Size(360, 800),
      'short wide phone': Size(480, 560),
      'tablet portrait': Size(800, 1280),
      'tablet landscape': Size(1280, 800),
      'phone landscape': Size(844, 390),
      'ultra-wide': Size(2400, 600),
    };
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets(name, (tester) async {
        _setScreen(tester, size);
        await tester.pumpWidget(
          GridVoltApp(
            soundEffects: const SilentSoundEffects(),
            gameBloc: _seededBloc(),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(TraySlot), findsNWidgets(3));
        expect(find.byKey(const ValueKey('cell-7-7')), findsOneWidget);

        final cell = tester.getSize(find.byKey(const ValueKey('cell-0-0')));
        expect(cell.width, closeTo(cell.height, 0.01), reason: 'square cells');
      });
    }
  });

  group('drag and drop', () {
    testWidgets('valid drop previews, places the shape and plays a sound', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      final bloc = _seededBloc();
      final sfx = RecordingSoundEffects();
      await tester.pumpWidget(GridVoltApp(soundEffects: sfx, gameBloc: bloc));
      await tester.pump();

      final shape = bloc.state.trayShapes.first;
      final cellRect = tester.getRect(find.byKey(const ValueKey('cell-0-0')));
      final pointer =
          cellRect.center -
          TrayDragGeometry.feedbackOffset(shape, cellRect.width);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(shape.id))),
      );
      await tester.pump();
      await gesture.moveTo(pointer);
      await tester.pump();
      expect(_validPreview(), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(bloc.state.trayShapes.length, 2);
      expect(bloc.state.currentScore, shape.cells.length);
      for (final c in shape.cells) {
        expect(bloc.state.gridMatrix[c.row][c.col].colorId, shape.colorId);
      }
      expect(_validPreview(), findsNothing);
      expect(sfx.played, [Sfx.drop]);
    });

    testWidgets('drop off the board flies the shape back to its slot', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      final bloc = _seededBloc();
      await tester.pumpWidget(
        GridVoltApp(soundEffects: const SilentSoundEffects(), gameBloc: bloc),
      );
      await tester.pump();

      final shape = bloc.state.trayShapes.first;
      final slot = find.byKey(ValueKey(shape.id));
      final gesture = await tester.startGesture(tester.getCenter(slot));
      await tester.pump();
      await gesture.moveTo(const Offset(380, 830)); // bottom-right, off-board
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      double slotOpacity() => tester
          .widget<Opacity>(
            find.descendant(of: slot, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(slotOpacity(), 0, reason: 'hidden while the return flight runs');

      await tester.pumpAndSettle();
      expect(slotOpacity(), 1);
      expect(bloc.state.trayShapes.length, 3);
      expect(bloc.state.currentScore, 0);
    });

    testWidgets('mute toggle silences sound effects', (tester) async {
      _setScreen(tester, const Size(390, 844));
      final bloc = _seededBloc();
      final sfx = RecordingSoundEffects();
      await tester.pumpWidget(GridVoltApp(soundEffects: sfx, gameBloc: bloc));
      await tester.pump();

      await tester.tap(find.byTooltip('Mute'));
      await tester.pump();
      bloc.add(PlaceShape(bloc.state.trayShapes.first, 0, 0));
      await tester.pumpAndSettle();

      expect(bloc.state.trayShapes.length, 2);
      expect(sfx.played, isEmpty);
    });
  });

  testWidgets('game over shows the dialog and Replay restarts', (tester) async {
    _setScreen(tester, const Size(390, 844));
    final bloc = MockGameBloc();
    final sfx = RecordingSoundEffects();
    final playing = GameState.initial(
      highScore: 50,
    ).copyWith(trayShapes: const [dot]);
    final over = playing.copyWith(
      currentScore: 80,
      highScore: 80,
      isGameOver: true,
    );
    whenListen(bloc, Stream.fromIterable([over]), initialState: playing);

    await tester.pumpWidget(GridVoltApp(soundEffects: sfx, gameBloc: bloc));
    await tester.pump();
    await tester.pump(GameScreen.gameOverDelay);
    await tester.pumpAndSettle();

    expect(sfx.played, [Sfx.gameOver]);
    expect(find.text('CIRCUIT OVERLOAD'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('game-over-score'))).data,
      '80',
    );
    expect(find.text('NEW HIGH SCORE'), findsOneWidget);

    await tester.tap(find.text('REPLAY'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const StartNewGame())).called(1);
    expect(find.text('CIRCUIT OVERLOAD'), findsNothing);
  });
}
