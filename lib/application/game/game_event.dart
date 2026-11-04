part of 'game_bloc.dart';

sealed class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

/// Resets score and grid, deals a fresh tray of 3 shapes.
final class StartNewGame extends GameEvent {
  const StartNewGame();
}

/// Sent on app launch: continues a restored run if there is one, otherwise
/// starts a new game.
final class ResumeOrStartGame extends GameEvent {
  const ResumeOrStartGame();
}

/// Attempts to drop [shape] (which must be in the tray) at the given origin.
final class PlaceShape extends GameEvent {
  const PlaceShape(this.shape, this.originRow, this.originCol);

  final PuzzleShape shape;
  final int originRow;
  final int originCol;

  @override
  List<Object?> get props => [shape, originRow, originCol];
}

/// Deals 3 new shapes, but only once the tray has been emptied.
final class ReplenishTrayIfNeeded extends GameEvent {
  const ReplenishTrayIfNeeded();
}
