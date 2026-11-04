part of 'game_bloc.dart';

/// JSON persistence for [GameState].
///
/// Always stores the high score. While a run is in progress it also stores
/// the board, tray and score, so a game survives the app being killed. A
/// finished run is not stored; the next launch starts fresh. Anything
/// unreadable falls back to a new game that keeps the high score.
abstract final class GameStateCodec {
  static const int version = 2;

  static Map<String, dynamic> encode(GameState s) {
    final inProgress =
        !s.isGameOver && (s.trayShapes.isNotEmpty || s.currentScore > 0);
    return {
      'v': version,
      'highScore': s.highScore,
      if (inProgress)
        'run': {
          'score': s.currentScore,
          'highScoreAtStart': s.highScoreAtStart,
          'grid': [
            for (final row in s.gridMatrix)
              [for (final cell in row) _encodeCell(cell)],
          ],
          'tray': [for (final shape in s.trayShapes) _encodeShape(shape)],
        },
    };
  }

  static GameState decode(Map<String, dynamic> json) {
    final storedHigh = json['highScore'];
    final highScore = storedHigh is int && storedHigh >= 0 ? storedHigh : 0;
    final run = json['run'];
    if (run is! Map) return GameState.initial(highScore: highScore);

    try {
      final size = GridVoltEngine.defaultSize;
      final rows = run['grid'] as List;
      if (rows.length != size) throw const FormatException('grid rows');
      final grid = List<List<GridCell>>.unmodifiable([
        for (final row in rows)
          List<GridCell>.unmodifiable([
            for (final cell in (row as List).cast<int>()) _decodeCell(cell),
          ]),
      ]);
      if (grid.any((r) => r.length != size)) {
        throw const FormatException('grid cols');
      }
      final tray = List<PuzzleShape>.unmodifiable([
        for (final s in run['tray'] as List)
          _decodeShape((s as Map).cast<String, dynamic>()),
      ]);
      if (tray.length > 3) throw const FormatException('tray');

      final score = run['score'] as int;
      return GameState(
        gridMatrix: grid,
        trayShapes: tray,
        currentScore: score,
        highScore: max(highScore, score),
        highScoreAtStart: run['highScoreAtStart'] as int? ?? highScore,
        isGameOver: false,
      );
    } on Object {
      return GameState.initial(highScore: highScore);
    }
  }

  // Cell: colorId in the low byte, special tile index above it.
  static int _encodeCell(GridCell c) => c.colorId | (c.special.index << 8);

  static GridCell _decodeCell(int v) {
    final special = v >> 8;
    if (special >= SpecialTile.values.length) {
      throw const FormatException('special');
    }
    return GridCell(colorId: v & 0xFF, special: SpecialTile.values[special]);
  }

  static Map<String, dynamic> _encodeShape(PuzzleShape s) => {
    'id': s.id,
    'cells': [
      for (final c in s.cells) [c.row, c.col],
    ],
    'colorId': s.colorId,
    'special': s.special.name,
    'specialIndex': s.specialIndex,
  };

  static PuzzleShape _decodeShape(Map<String, dynamic> j) {
    final cells = [
      for (final c in j['cells'] as List)
        CellOffset((c as List)[0] as int, c[1] as int),
    ];
    if (cells.isEmpty) throw const FormatException('cells');
    final colorId = j['colorId'] as int;
    if (colorId <= 0) throw const FormatException('color');
    return PuzzleShape(
      id: j['id'] as String,
      cells: List.unmodifiable(cells),
      colorId: colorId,
      special: SpecialTile.values.byName(j['special'] as String),
      specialIndex: j['specialIndex'] as int,
    );
  }
}
