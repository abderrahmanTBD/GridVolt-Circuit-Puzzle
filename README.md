# GridVolt: Circuit Puzzle

[![CI](https://github.com/abderrahmanTBD/GridVolt-Circuit-Puzzle/actions/workflows/main.yml/badge.svg)](https://github.com/abderrahmanTBD/GridVolt-Circuit-Puzzle/actions/workflows/main.yml)

A neon, dark-mode block-placement puzzle for Android and iOS. Drag circuit
pieces from the tray onto an 8 × 8 power grid; complete rows or columns to
discharge them. Built with Flutter, `flutter_bloc` and a pure-Dart rules engine.

## Gameplay

- Three pieces are dealt at a time. A new set arrives once all three are placed.
- Fill a full row or column to clear it. Clearing several lines in one move
  scores a combo bonus (10 × lines²).
- **Battery tiles** 🔋 explode when cleared, wiping their 3 × 3 neighbourhood
  and chaining into any other battery caught in the blast.
- **Multiplier tiles** `×2` double the points of the move that clears them
  (they stack, up to ×8).
- The game ends when none of the remaining pieces fits. The high score persists
  across restarts.

## Architecture

```
lib/
├── domain/                 Pure Dart — no Flutter imports
│   ├── engine/             GridVoltEngine (rules, scoring), ShapeGenerator
│   └── models/             GridCell, PuzzleShape, MoveResult, SpecialTile, palette
├── application/            State management
│   ├── game/               GameBloc (HydratedBloc: persists high score)
│   └── settings/           AudioSettingsCubit (persisted mute)
├── presentation/
│   ├── screens/            GameScreen + responsive layout
│   ├── widgets/            Board, tray, HUD, Game Over dialog, cells
│   ├── painters/           Circuit panels, placement preview, line-clear FX
│   ├── effects/            Sound effects (audioplayers)
│   └── theme/
├── app.dart                Providers + MaterialApp
└── main.dart               Storage + audio bootstrap
```

**Data flow:** tray `Draggable` → board-cell `DragTarget` → `PlaceShape` event →
`GridVoltEngine.applyMove` → new `GameState` → widgets rebuild. Animations and
sounds respond to `lastMoveResult` through `BlocListener`s.

**Drag precision.** The drag feedback is drawn at board scale and lifted above
the finger. `Draggable.feedbackOffset` aims the hit-test point at the centre of
the piece's top-left cell, so the cell under that point is the placement
origin. Drops that don't fit are rejected in `onWillAcceptWithDetails`, which
cancels the drag, and the piece flies back to its tray slot.

## Running

```bash
flutter pub get
flutter run
```

Sound effects are generated procedurally, so there are no third-party audio
assets. To regenerate them:

```bash
dart run tool/generate_sounds.dart
```

## Testing

```bash
flutter analyze
flutter test
```

The suite covers the engine (scoring, surges, multipliers), the bloc (tray,
score, high-score persistence, game over) and the UI (layout at 8 screen sizes
without overflow, drag-and-drop placement, return-to-tray, mute, the Game Over
dialog). CI runs analyze and test on every push via
[`.github/workflows/main.yml`](.github/workflows/main.yml).
