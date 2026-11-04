// Renders the README screenshots and gameplay GIF from the real widgets.
//
//   flutter test tool/readme_media
//
// Output: docs/media/*.png and docs/media/gameplay.gif. Lives outside test/
// so CI's `flutter test` doesn't regenerate it.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements Storage {}

const _screen = Size(390, 844);
const _rootKey = Key('media-root');
final _outDir = Directory('docs/media');

// ---------------------------------------------------------------------------
// Fixtures

/// '.' empty, '1'-'6' color, 'B' battery, 'M' multiplier.
List<List<GridCell>> _grid(List<String> rows) => List.unmodifiable([
  for (final row in rows)
    List<GridCell>.unmodifiable([
      for (final ch in row.split(''))
        switch (ch) {
          '.' => GridCell.empty,
          'B' => const GridCell(colorId: 2, special: SpecialTile.battery),
          'M' => const GridCell(colorId: 3, special: SpecialTile.multiplier),
          final d => GridCell(colorId: int.parse(d)),
        },
    ]),
]);

/// Placing [_combo] at (4,3) completes row 4 and column 3, detonating the
/// battery at (4,1) and clearing the ×2 multiplier at (5,3).
final _showcase = _grid(const [
  '1.23.6..',
  '1..4..5.',
  '11.5.66.',
  '...6..2.',
  '2B5..143',
  '.66M.1..',
  '33.1.2.4',
  '3..2..44',
]);

const _combo = PuzzleShape(
  id: 'combo',
  cells: [CellOffset(0, 0), CellOffset(0, 1)],
  colorId: 1,
);
const _batteryL = PuzzleShape(
  id: 'batteryL',
  cells: [CellOffset(0, 0), CellOffset(1, 0), CellOffset(1, 1)],
  colorId: 5,
  special: SpecialTile.battery,
  specialIndex: 2,
);
const _tee = PuzzleShape(
  id: 'tee',
  cells: [
    CellOffset(0, 0),
    CellOffset(0, 1),
    CellOffset(0, 2),
    CellOffset(1, 1),
  ],
  colorId: 6,
);

GameState _midGame() => GameState(
  gridMatrix: _showcase,
  trayShapes: const [_combo, _batteryL, _tee],
  currentScore: 1240,
  highScore: 2810,
  highScoreAtStart: 2810,
  isGameOver: false,
);

/// Nearly full, colorful board: placing [_h2] at (0,0) completes no line and
/// leaves no 2×2 gap, so the remaining square can't fit -> game over.
GameState _almostOver() {
  final rnd = Random(11);
  final g = [
    for (var r = 0; r < 8; r++)
      [
        for (var c = 0; c < 8; c++)
          GridCell(colorId: 1 + rnd.nextInt(VoltPalette.shapeColorCount)),
      ],
  ];
  for (var i = 1; i < 8; i++) {
    g[i][i] = GridCell.empty;
  }
  for (final (r, c) in [(0, 0), (0, 1), (0, 7), (7, 0)]) {
    g[r][c] = GridCell.empty;
  }
  return GameState(
    gridMatrix: g,
    trayShapes: const [_h2, _square],
    currentScore: 3460,
    highScore: 3415,
    highScoreAtStart: 3415,
    isGameOver: false,
  );
}

const _h2 = PuzzleShape(
  id: 'h2',
  cells: [CellOffset(0, 0), CellOffset(0, 1)],
  colorId: 2,
);
const _square = PuzzleShape(
  id: 'sq',
  cells: [
    CellOffset(0, 0),
    CellOffset(0, 1),
    CellOffset(1, 0),
    CellOffset(1, 1),
  ],
  colorId: 4,
);

// ---------------------------------------------------------------------------
// Harness

Future<void> _loadFonts() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final fonts = Directory('${artifacts.path}/material_fonts');
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(read('roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('materialicons-regular.otf'))).load();
}

Future<GameBloc> _pumpApp(
  WidgetTester tester, {
  required GameState? saved,
  bool tutorialSeen = true,
}) async {
  final storage = _MockStorage();
  when(() => storage.read(any())).thenReturn(null);
  when(() => storage.write(any(), any<dynamic>())).thenAnswer((_) async {});
  if (saved != null) {
    when(
      () => storage.read('GameBloc'),
    ).thenReturn(GameStateCodec.encode(saved));
  }
  if (tutorialSeen) {
    when(() => storage.read('OnboardingCubit')).thenReturn({
      'tutorialSeen': true,
      'hintsSeen': ['battery', 'multiplier'],
    });
  }
  HydratedBloc.storage = storage;

  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final bloc = GameBloc(
    shapeGenerator: ShapeGenerator(random: Random(21), specialChance: 0.3),
  )..add(const ResumeOrStartGame());
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: GridVoltApp(
        soundEffects: const SilentSoundEffects(),
        gameBloc: bloc,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600)); // HUD count-up
  return bloc;
}

Future<ui.Image> _capture(WidgetTester tester, double pixelRatio) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_rootKey),
  );
  return (await tester.runAsync(
    () => boundary.toImage(pixelRatio: pixelRatio),
  ))!;
}

Future<void> _savePng(WidgetTester tester, String name) async {
  final image = await _capture(tester, 2);
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  image.dispose();
  _outDir.createSync(recursive: true);
  File(
    '${_outDir.path}/$name.png',
  ).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Records frames for the GIF at a reduced scale.
class _GifRecorder {
  _GifRecorder(this.tester);

  final WidgetTester tester;
  final frames = <(img.Image, int)>[];
  static const scale = 0.8;

  Future<void> frame({int centiseconds = 4}) async {
    final image = await _capture(tester, scale);
    final raw = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    frames.add((
      img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: raw!.buffer,
        numChannels: 4,
      ),
      centiseconds,
    ));
    image.dispose();
  }

  void save(String name) {
    final encoder = img.GifEncoder(repeat: 0, dither: img.DitherKernel.none);
    for (final (frame, duration) in frames) {
      encoder.addFrame(frame, duration: duration);
    }
    File('${_outDir.path}/$name.gif').writeAsBytesSync(encoder.finish()!);
  }
}

// ---------------------------------------------------------------------------
// Scenes

void main() {
  setUpAll(_loadFonts);

  testWidgets('tutorial', (tester) async {
    await _pumpApp(tester, saved: _midGame(), tutorialSeen: false);
    await tester.pump(const Duration(milliseconds: 950)); // piece mid-slide
    await _savePng(tester, 'tutorial');
  });

  testWidgets('gameplay, drag preview, line clear + GIF', (tester) async {
    final bloc = await _pumpApp(tester, saved: _midGame());
    expect(bloc.state.trayShapes, hasLength(3));
    await _savePng(tester, 'gameplay');

    final gif = _GifRecorder(tester);
    await gif.frame(centiseconds: 70);

    final cell = tester.getRect(find.byKey(const ValueKey('cell-4-3')));
    final from = tester.getCenter(find.byKey(const ValueKey('combo')));
    final to =
        cell.center - TrayDragGeometry.feedbackOffset(_combo, cell.width);

    final gesture = await tester.startGesture(from);
    await tester.pump();
    const steps = 14;
    for (var i = 1; i <= steps; i++) {
      final t = Curves.easeInOut.transform(i / steps);
      await gesture.moveTo(Offset.lerp(from, to, t)!);
      await tester.pump(const Duration(milliseconds: 30));
      await gif.frame(centiseconds: 3);
    }
    await gif.frame(centiseconds: 80); // hold on the preview
    await _savePng(tester, 'drag_preview');

    await gesture.up();
    await tester.pump();
    for (var ms = 0; ms < 1000; ms += 40) {
      await tester.pump(const Duration(milliseconds: 40));
      await gif.frame();
      if (ms == 120) await _savePng(tester, 'line_clear');
    }
    await tester.pumpAndSettle();
    await gif.frame(centiseconds: 160);

    final result = bloc.state.lastMoveResult!;
    expect(result.clearedLinesCount, 2);
    expect(result.batterySurgeCount, 1);
    expect(result.multiplier, 2);

    gif.save('gameplay');
  });

  testWidgets('game over', (tester) async {
    final bloc = await _pumpApp(tester, saved: _almostOver());
    bloc.add(const PlaceShape(_h2, 0, 0));
    await tester.pump();
    expect(bloc.state.isGameOver, isTrue);
    expect(
      GridVoltEngine.hasValidMoves(bloc.state.gridMatrix, [_square]),
      isFalse,
    );
    await tester.pump(GameScreen.gameOverDelay);
    await tester.pumpAndSettle();
    expect(find.text('NEW HIGH SCORE'), findsOneWidget);
    await _savePng(tester, 'game_over');
  });
}
