import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../domain/engine/grid_volt_engine.dart';
import '../../domain/engine/shape_generator.dart';
import '../../domain/models/models.dart';

part 'game_event.dart';
part 'game_state.dart';

/// Game state machine. Only [GameState.highScore] is persisted (via
/// hydrated_bloc), so it survives app restarts while a run in progress does not.
class GameBloc extends HydratedBloc<GameEvent, GameState> {
  GameBloc({ShapeGenerator? shapeGenerator})
    : _generator = shapeGenerator ?? ShapeGenerator(),
      super(GameState.initial()) {
    on<StartNewGame>(_onStartNewGame);
    on<PlaceShape>(_onPlaceShape);
    on<ReplenishTrayIfNeeded>(_onReplenishTrayIfNeeded);
  }

  final ShapeGenerator _generator;

  static const _highScoreKey = 'highScore';

  void _onStartNewGame(StartNewGame event, Emitter<GameState> emit) {
    emit(
      GameState.initial(
        highScore: state.highScore,
      ).copyWith(trayShapes: _generator.nextTray()),
    );
  }

  void _onPlaceShape(PlaceShape event, Emitter<GameState> emit) {
    if (state.isGameOver) return;

    final trayIndex = state.trayShapes.indexWhere(
      (s) => s.id == event.shape.id,
    );
    if (trayIndex == -1) return; // not in tray (stale drag / double drop)

    if (!GridVoltEngine.canPlaceShape(
      state.gridMatrix,
      event.shape,
      event.originRow,
      event.originCol,
    )) {
      return;
    }

    final result = GridVoltEngine.applyMove(
      state.gridMatrix,
      event.shape,
      event.originRow,
      event.originCol,
    );

    final remainingTray = List<PuzzleShape>.unmodifiable(
      [...state.trayShapes]..removeAt(trayIndex),
    );
    final newScore = state.currentScore + result.pointsEarned;

    // With an empty tray the game-over check is deferred until the new tray
    // has been dealt in ReplenishTrayIfNeeded.
    final isGameOver =
        remainingTray.isNotEmpty &&
        !GridVoltEngine.hasValidMoves(result.grid, remainingTray);

    emit(
      state.copyWith(
        gridMatrix: result.grid,
        trayShapes: remainingTray,
        currentScore: newScore,
        highScore: max(state.highScore, newScore),
        isGameOver: isGameOver,
        lastMoveResult: () => result,
      ),
    );

    if (remainingTray.isEmpty) add(const ReplenishTrayIfNeeded());
  }

  void _onReplenishTrayIfNeeded(
    ReplenishTrayIfNeeded event,
    Emitter<GameState> emit,
  ) {
    if (state.trayShapes.isNotEmpty || state.isGameOver) return;

    final tray = _generator.nextTray();
    emit(
      state.copyWith(
        trayShapes: tray,
        isGameOver: !GridVoltEngine.hasValidMoves(state.gridMatrix, tray),
      ),
    );
  }

  @override
  GameState? fromJson(Map<String, dynamic> json) {
    final stored = json[_highScoreKey];
    return GameState.initial(highScore: stored is int ? stored : 0);
  }

  @override
  Map<String, dynamic>? toJson(GameState state) => {
    _highScoreKey: state.highScore,
  };
}
