import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../domain/engine/grid_volt_engine.dart';
import '../../domain/engine/shape_generator.dart';
import '../../domain/models/models.dart';

part 'game_event.dart';
part 'game_state.dart';
part 'game_state_codec.dart';

/// Game state machine, persisted with hydrated_bloc: the high score always,
/// plus the board, tray and score while a run is in progress (see
/// [GameStateCodec]).
class GameBloc extends HydratedBloc<GameEvent, GameState> {
  GameBloc({ShapeGenerator? shapeGenerator})
    : _generator = shapeGenerator ?? ShapeGenerator(),
      super(GameState.initial()) {
    on<StartNewGame>(_onStartNewGame);
    on<ResumeOrStartGame>(_onResumeOrStartGame);
    on<PlaceShape>(_onPlaceShape);
    on<ReplenishTrayIfNeeded>(_onReplenishTrayIfNeeded);
  }

  final ShapeGenerator _generator;

  void _onStartNewGame(StartNewGame event, Emitter<GameState> emit) {
    final grid = GridVoltEngine.emptyGrid();
    emit(
      GameState.initial(highScore: state.highScore).copyWith(
        gridMatrix: grid,
        trayShapes: _generator.nextTray(grid: grid),
      ),
    );
  }

  void _onResumeOrStartGame(ResumeOrStartGame event, Emitter<GameState> emit) {
    final hasRun = state.trayShapes.isNotEmpty || state.currentScore > 0;
    if (state.isGameOver || !hasRun) {
      _onStartNewGame(const StartNewGame(), emit);
    } else if (state.trayShapes.isEmpty) {
      _onReplenishTrayIfNeeded(const ReplenishTrayIfNeeded(), emit);
    }
    // Otherwise the restored run continues as-is.
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

    final tray = _generator.nextTray(grid: state.gridMatrix);
    emit(
      state.copyWith(
        trayShapes: tray,
        isGameOver: !GridVoltEngine.hasValidMoves(state.gridMatrix, tray),
      ),
    );
  }

  @override
  GameState? fromJson(Map<String, dynamic> json) => GameStateCodec.decode(json);

  @override
  Map<String, dynamic>? toJson(GameState state) => GameStateCodec.encode(state);
}
