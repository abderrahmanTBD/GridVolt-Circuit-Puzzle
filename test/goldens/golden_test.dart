@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/application/game/game_bloc.dart';
import 'package:grid_volt/domain/models/models.dart';
import 'package:grid_volt/presentation/theme/volt_theme.dart';
import 'package:grid_volt/presentation/widgets/game_board.dart';
import 'package:grid_volt/presentation/widgets/game_over_dialog.dart';
import 'package:grid_volt/presentation/widgets/placement_preview.dart';
import 'package:grid_volt/presentation/widgets/shape_view.dart';

import '../helpers.dart';

/// Regenerate after an intentional visual change with:
///   flutter test --update-goldens test/goldens
void main() {
  setUp(installMockStorage);

  /// A varied mid-game board: every color, both special tiles.
  List<List<GridCell>> showcaseGrid() {
    final g = mutableGrid();
    const rows = [
      '1.2..33.',
      '1.2...3.',
      '11....44',
      '.....5..',
      '6B6..5..',
      '666..55M',
      '222111..',
      '2..1.3..',
    ];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        g[r][c] = switch (rows[r][c]) {
          '.' => GridCell.empty,
          'B' => const GridCell(colorId: 2, special: SpecialTile.battery),
          'M' => const GridCell(colorId: 3, special: SpecialTile.multiplier),
          final d => GridCell(colorId: int.parse(d)),
        };
      }
    }
    return g;
  }

  Widget host(Widget child, {Size size = const Size(360, 360)}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: VoltTheme.dark(),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const Key('golden'),
            child: ColoredBox(
              color: VoltColors.background,
              child: SizedBox.fromSize(
                size: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  GameState stateWith(List<List<GridCell>> grid) => GameState(
    gridMatrix: grid,
    trayShapes: const [],
    currentScore: 0,
    highScore: 0,
    isGameOver: false,
  );

  testWidgets('board with pieces and special tiles', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = GameBloc()..emit(stateWith(showcaseGrid()));
    addTearDown(bloc.close);
    final preview = PlacementPreviewController(null);
    addTearDown(preview.dispose);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: host(GameBoard(size: 340, preview: preview)),
      ),
    );
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/board.png'),
    );
  });

  testWidgets('board placement previews (fits / does not fit)', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final grid = showcaseGrid();
    final bloc = GameBloc()..emit(stateWith(grid));
    addTearDown(bloc.close);
    final preview = PlacementPreviewController(null);
    addTearDown(preview.dispose);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: host(GameBoard(size: 340, preview: preview)),
      ),
    );

    // Completes row 6 -> valid preview with the row highlighted.
    preview.value = PlacementPreview.compute(grid, h2, 6, 6);
    await tester.pump();
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/board_preview_valid.png'),
    );

    // Overlaps existing cells -> red preview.
    preview.value = PlacementPreview.compute(grid, square, 0, 1);
    await tester.pump();
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/board_preview_invalid.png'),
    );
  });

  testWidgets('tray pieces', (tester) async {
    tester.view.physicalSize = const Size(400, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const battery = PuzzleShape(
      id: 'b',
      cells: [CellOffset(0, 0), CellOffset(1, 0), CellOffset(1, 1)],
      colorId: 2,
      special: SpecialTile.battery,
      specialIndex: 2,
    );
    const mult = PuzzleShape(
      id: 'm',
      cells: [CellOffset(0, 0), CellOffset(0, 1), CellOffset(0, 2)],
      colorId: 5,
      special: SpecialTile.multiplier,
    );
    await tester.pumpWidget(
      host(
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ShapeView(shape: square, cellSize: 28),
            ShapeView(shape: battery, cellSize: 28),
            ShapeView(shape: mult, cellSize: 28),
          ],
        ),
        size: const Size(380, 120),
      ),
    );
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/tray_pieces.png'),
    );
  });

  for (final newRecord in [true, false]) {
    testWidgets('game over dialog (new record: $newRecord)', (tester) async {
      tester.view.physicalSize = const Size(400, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          GameOverDialog(
            score: 1280,
            highScore: newRecord ? 1280 : 2048,
            isNewHighScore: newRecord,
            onReplay: () {},
          ),
          size: const Size(400, 600),
        ),
      );
      await expectLater(
        find.byKey(const Key('golden')),
        matchesGoldenFile(
          'goldens/game_over_${newRecord ? 'record' : 'regular'}.png',
        ),
      );
    });
  }
}
