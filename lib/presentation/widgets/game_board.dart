import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/game/game_bloc.dart';
import '../../domain/engine/grid_volt_engine.dart';
import '../../domain/models/models.dart';
import '../painters/line_clear_painter.dart';
import '../painters/placement_preview_painter.dart';
import '../theme/volt_theme.dart';
import 'placement_preview.dart';
import 'shape_view.dart';
import 'volt_cell.dart';

/// The square 8×8 board. Every cell is a [DragTarget]; a preview overlay shows
/// where the hovered shape would land, and a painter plays line-clear effects.
class GameBoard extends StatefulWidget {
  const GameBoard({super.key, required this.size, required this.preview});

  final double size;
  final PlacementPreviewController preview;

  static double frameFor(double size) => size * 0.025;

  static double cellSizeFor(double size) =>
      (size - 2 * frameFor(size)) / GridVoltEngine.defaultSize;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late final AnimationController _clear;
  late final AnimationController _popup;
  MoveResult? _clearEffect;
  MoveResult? _popupResult;

  @override
  void initState() {
    super.initState();
    _clear = AnimationController(vsync: this);
    _popup = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _clear.dispose();
    _popup.dispose();
    super.dispose();
  }

  void _onMove(MoveResult result) {
    setState(() => _popupResult = result);
    _popup.forward(from: 0);
    if (result.clearedLinesCount > 0) {
      setState(() => _clearEffect = result);
      _clear.duration = Duration(
        milliseconds: result.batterySurgeCount > 0 ? 950 : 620,
      );
      _clear.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = GameBoard.frameFor(widget.size);
    final cell = GameBoard.cellSizeFor(widget.size);

    return BlocListener<GameBloc, GameState>(
      listenWhen: (p, c) =>
          p.lastMoveResult != c.lastMoveResult && c.lastMoveResult != null,
      listener: (_, s) => _onMove(s.lastMoveResult!),
      child: AnimatedBuilder(
        animation: _clear,
        builder: (context, child) {
          final effect = _clearEffect;
          final t = _clear.value;
          final shake =
              effect != null &&
                  effect.batterySurgeCount > 0 &&
                  _clear.isAnimating
              ? sin(t * pi * 14) * cell * 0.09 * (1 - t)
              : 0.0;
          return Transform.translate(offset: Offset(shake, 0), child: child);
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          padding: EdgeInsets.all(frame),
          decoration: BoxDecoration(
            color: VoltColors.boardFrame,
            borderRadius: BorderRadius.circular(frame * 2.4),
            border: Border.all(
              color: VoltColors.accent.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: VoltColors.accent.withValues(alpha: 0.1),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              BlocBuilder<GameBloc, GameState>(
                buildWhen: (p, c) => p.gridMatrix != c.gridMatrix,
                builder: (context, state) => _Grid(
                  grid: state.gridMatrix,
                  cellSize: cell,
                  preview: widget.preview,
                ),
              ),
              IgnorePointer(
                child: ValueListenableBuilder<PlacementPreview?>(
                  valueListenable: widget.preview,
                  builder: (_, preview, _) => CustomPaint(
                    painter: PlacementPreviewPainter(
                      preview: preview,
                      cellSize: cell,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _clear,
                  builder: (_, _) {
                    final effect = _clearEffect;
                    if (effect == null || !_clear.isAnimating) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: LineClearPainter(
                        result: effect,
                        progress: _clear.value,
                        cellSize: cell,
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: _ScorePopup(
                  animation: _popup,
                  result: _popupResult,
                  cellSize: cell,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.grid,
    required this.cellSize,
    required this.preview,
  });

  final GridMatrix grid;
  final double cellSize;
  final PlacementPreviewController preview;

  @override
  Widget build(BuildContext context) {
    final n = grid.length;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n,
      ),
      itemCount: n * n,
      itemBuilder: (context, i) {
        final r = i ~/ n;
        final c = i % n;
        return _BoardCellTarget(
          key: ValueKey('cell-$r-$c'),
          row: r,
          col: c,
          grid: grid,
          cellSize: cellSize,
          preview: preview,
        );
      },
    );
  }
}

class _BoardCellTarget extends StatelessWidget {
  const _BoardCellTarget({
    super.key,
    required this.row,
    required this.col,
    required this.grid,
    required this.cellSize,
    required this.preview,
  });

  final int row;
  final int col;
  final GridMatrix grid;
  final double cellSize;
  final PlacementPreviewController preview;

  @override
  Widget build(BuildContext context) {
    final inset = ShapeView.cellInset(cellSize);
    return DragTarget<PuzzleShape>(
      // Rejecting here (rather than ignoring the drop later) makes Flutter
      // treat the drop as cancelled, which triggers the return-to-tray
      // animation.
      onWillAcceptWithDetails: (d) {
        final p = PlacementPreview.compute(grid, d.data, row, col);
        preview.value = p;
        return p.isValid;
      },
      onLeave: (_) {
        if (preview.value?.isAt(row, col) ?? false) preview.value = null;
      },
      onAcceptWithDetails: (d) {
        preview.value = null;
        context.read<GameBloc>().add(PlaceShape(d.data, row, col));
      },
      builder: (_, _, _) => Padding(
        padding: EdgeInsets.all(inset),
        child: VoltCell(cell: grid[row][col], size: cellSize - 2 * inset),
      ),
    );
  }
}

/// Floating "+points ×mult" that rises from where the shape was placed.
class _ScorePopup extends StatelessWidget {
  const _ScorePopup({
    required this.animation,
    required this.result,
    required this.cellSize,
  });

  final Animation<double> animation;
  final MoveResult? result;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final color = Color(r.shape.colorHex);
    final big = r.clearedLinesCount > 0;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final rise = Curves.easeOut.transform(t) * cellSize * 1.3;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: (r.originCol + r.shape.colCount / 2) * cellSize,
              top: (r.originRow + r.shape.rowCount / 2) * cellSize - rise,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Opacity(
                  opacity: (1 - t * t).clamp(0.0, 1.0),
                  child: Text(
                    '+${r.pointsEarned}'
                    '${r.multiplier > 1 ? '  ×${r.multiplier}' : ''}',
                    style: TextStyle(
                      fontSize: cellSize * (big ? 0.62 : 0.42),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: color, blurRadius: 12),
                        Shadow(color: color, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
