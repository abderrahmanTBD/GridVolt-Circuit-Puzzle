import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/volt_theme.dart';
import 'shape_view.dart';
import 'volt_cell.dart';

/// Three-step "how to play" card shown on first launch (and from the HUD's
/// help button). Calls [onDone] with `finished: true` after the last step,
/// or `false` when skipped.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.onDone});

  final void Function({required bool finished}) onDone;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  int _step = 0;

  static const _steps = [
    (
      title: 'Power the grid',
      body:
          'Drag pieces from the tray onto the board. Pieces can\'t be '
          'rotated, and the preview turns red where one won\'t fit.',
    ),
    (
      title: 'Discharge lines',
      body:
          'Fill a whole row or column to clear it. Clear several lines in '
          'one move for a big combo bonus.',
    ),
    (
      title: 'Special tiles',
      body:
          'The game ends when none of your pieces fit, so keep space open '
          'and use these to break out of tight spots.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _steps.length - 1) {
      widget.onDone(finished: true);
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Material(
      key: const Key('tutorial-overlay'),
      color: Colors.black.withValues(alpha: 0.6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VoltColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: VoltColors.accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'HOW TO PLAY  ${_step + 1}/${_steps.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w700,
                            color: VoltColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: switch (_step) {
                                0 => _DragDemo(animation: _loop),
                                1 => _ClearDemo(animation: _loop),
                                _ => const _SpecialsDemo(),
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            height: 1.4,
                            color: VoltColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Dots(count: _steps.length, active: _step),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (!isLast)
                              TextButton(
                                onPressed: () => widget.onDone(finished: false),
                                child: const Text('Skip'),
                              ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                backgroundColor: VoltColors.accent,
                                foregroundColor: VoltColors.background,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              child: Text(isLast ? 'PLAY' : 'NEXT'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? VoltColors.accent : VoltColors.panelBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

const double _demoCell = 28;

Widget _miniGrid(int rows, int cols, GridCell Function(int r, int c) cellAt) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var r = 0; r < rows; r++)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var c = 0; c < cols; c++)
              Padding(
                padding: const EdgeInsets.all(1.5),
                child: VoltCell(cell: cellAt(r, c), size: _demoCell - 3),
              ),
          ],
        ),
    ],
  );
}

/// A piece glides from below into an empty slot on a mini board.
class _DragDemo extends StatelessWidget {
  const _DragDemo({required this.animation});

  final Animation<double> animation;

  static const _piece = PuzzleShape(
    id: 'demo',
    cells: [CellOffset(0, 0), CellOffset(1, 0), CellOffset(1, 1)],
    colorId: 1,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final move = Curves.easeInOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
        final placed = t >= 0.6;
        final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
        const target = Offset(_demoCell, _demoCell);
        // Slides in from the right of the mini board, staying inside the box.
        const start = Offset(_demoCell * 5, _demoCell * 0.8);
        final pos = Offset.lerp(start, target, move)!;

        return Center(
          child: SizedBox(
            width: _demoCell * 7.5,
            height: _demoCell * 5,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                _miniGrid(4, 4, (r, c) {
                  final isTarget =
                      (r == 1 && c == 1) ||
                      (r == 2 && c == 1) ||
                      (r == 2 && c == 2);
                  if (placed && isTarget && fade > 0.5) {
                    return const GridCell(colorId: 1);
                  }
                  return (r == 3 || c == 3)
                      ? const GridCell(colorId: 6)
                      : GridCell.empty;
                }),
                if (!placed)
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: ShapeView(shape: _piece, cellSize: _demoCell),
                  ),
                if (!placed)
                  Positioned(
                    left: pos.dx + _demoCell * 0.9,
                    top: pos.dy + _demoCell * 2.1,
                    child: const Icon(
                      Icons.touch_app_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A row fills its last gap, flashes and empties.
class _ClearDemo extends StatelessWidget {
  const _ClearDemo({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final dropped = t >= 0.3;
        final flash = t >= 0.45 && t < 0.7;
        final cleared = t >= 0.7;
        final flashT = flash ? (t - 0.45) / 0.25 : 0.0;

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _miniGrid(3, 5, (r, c) {
                if (r == 1) {
                  if (cleared) return GridCell.empty;
                  if (c == 4 && !dropped) return GridCell.empty;
                  return GridCell(colorId: c == 4 ? 2 : 3);
                }
                return (r == 2 && c < 2)
                    ? const GridCell(colorId: 4)
                    : GridCell.empty;
              }),
              if (flash)
                IgnorePointer(
                  child: Container(
                    width: _demoCell * 5 + 8,
                    height: _demoCell * (1.2 - 0.6 * flashT),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.85 * (1 - flashT),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: VoltColors.accent.withValues(
                            alpha: 1 - flashT,
                          ),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              if (cleared)
                Opacity(
                  opacity: (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -12 * sin((t - 0.7) / 0.3 * pi / 2)),
                    child: const Text(
                      '+18',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: VoltColors.accent, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpecialsDemo extends StatelessWidget {
  const _SpecialsDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SpecialRow(
          tile: SpecialTile.battery,
          title: 'Battery',
          text: 'Explodes when its line clears, wiping its 3×3 area.',
        ),
        SizedBox(height: 14),
        _SpecialRow(
          tile: SpecialTile.multiplier,
          title: 'Multiplier',
          text: 'Doubles the points of the move that clears it.',
        ),
      ],
    );
  }
}

class _SpecialRow extends StatelessWidget {
  const _SpecialRow({
    required this.tile,
    required this.title,
    required this.text,
  });

  final SpecialTile tile;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        VoltCell(
          cell: GridCell(
            colorId: tile == SpecialTile.battery ? 2 : 3,
            special: tile,
          ),
          size: 48,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title  ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: text,
                  style: const TextStyle(color: VoltColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
