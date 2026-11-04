part of 'game_bloc.dart';

final class GameState extends Equatable {
  const GameState({
    required this.gridMatrix,
    required this.trayShapes,
    required this.currentScore,
    required this.highScore,
    required this.isGameOver,
    this.highScoreAtStart = 0,
    this.lastMoveResult,
  });

  factory GameState.initial({int highScore = 0}) => GameState(
    gridMatrix: GridVoltEngine.emptyGrid(),
    trayShapes: const [],
    currentScore: 0,
    highScore: highScore,
    highScoreAtStart: highScore,
    isGameOver: false,
  );

  final GridMatrix gridMatrix;

  /// Up to 3 shapes. Placed shapes are removed, so length shrinks 3 → 0.
  final List<PuzzleShape> trayShapes;
  final int currentScore;
  final int highScore;
  final bool isGameOver;

  /// The best score before this run began; used to detect a new record.
  final int highScoreAtStart;

  /// The most recent successful placement; null after a new game starts.
  /// Use with `BlocListener` to fire placement / line-clear animations.
  final MoveResult? lastMoveResult;

  bool get isNewHighScore => currentScore > highScoreAtStart;

  GameState copyWith({
    GridMatrix? gridMatrix,
    List<PuzzleShape>? trayShapes,
    int? currentScore,
    int? highScore,
    bool? isGameOver,
    int? highScoreAtStart,
    MoveResult? Function()? lastMoveResult,
  }) {
    return GameState(
      gridMatrix: gridMatrix ?? this.gridMatrix,
      trayShapes: trayShapes ?? this.trayShapes,
      currentScore: currentScore ?? this.currentScore,
      highScore: highScore ?? this.highScore,
      isGameOver: isGameOver ?? this.isGameOver,
      highScoreAtStart: highScoreAtStart ?? this.highScoreAtStart,
      lastMoveResult: lastMoveResult != null
          ? lastMoveResult()
          : this.lastMoveResult,
    );
  }

  @override
  List<Object?> get props => [
    gridMatrix,
    trayShapes,
    currentScore,
    highScore,
    isGameOver,
    highScoreAtStart,
    lastMoveResult,
  ];
}
