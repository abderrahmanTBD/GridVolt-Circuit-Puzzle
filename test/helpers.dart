import 'package:grid_volt/domain/engine/grid_volt_engine.dart';
import 'package:grid_volt/domain/models/models.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockStorage extends Mock implements Storage {}

/// Installs a mocked HydratedBloc storage. Unless [tutorialSeen] is false,
/// the first-run tutorial is marked as seen so it doesn't cover the board.
MockStorage installMockStorage({bool tutorialSeen = true}) {
  final storage = MockStorage();
  when(() => storage.read(any())).thenReturn(null);
  if (tutorialSeen) {
    when(
      () => storage.read('OnboardingCubit'),
    ).thenReturn({'tutorialSeen': true, 'hintsSeen': <String>[]});
  }
  when(() => storage.write(any(), any<dynamic>())).thenAnswer((_) async {});
  when(() => storage.delete(any())).thenAnswer((_) async {});
  when(() => storage.clear()).thenAnswer((_) async {});
  HydratedBloc.storage = storage;
  return storage;
}

const dot = PuzzleShape(id: 'dot', cells: [CellOffset(0, 0)], colorId: 1);
const h2 = PuzzleShape(
  id: 'h2',
  cells: [CellOffset(0, 0), CellOffset(0, 1)],
  colorId: 2,
);
const square = PuzzleShape(
  id: 'sq',
  cells: [
    CellOffset(0, 0),
    CellOffset(0, 1),
    CellOffset(1, 0),
    CellOffset(1, 1),
  ],
  colorId: 3,
);

const filled = GridCell(colorId: 5);

/// Mutable copy of an empty grid for building fixtures.
List<List<GridCell>> mutableGrid() => [
  for (final row in GridVoltEngine.emptyGrid()) List<GridCell>.of(row),
];

/// Grid where row 0 is full except its last cell.
List<List<GridCell>> almostFullRow0() {
  final g = mutableGrid();
  for (var c = 0; c < 7; c++) {
    g[0][c] = filled;
  }
  return g;
}
