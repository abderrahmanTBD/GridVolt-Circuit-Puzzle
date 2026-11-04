import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/game/game_bloc.dart';
import '../../domain/models/models.dart';
import '../theme/volt_theme.dart';
import 'shape_view.dart';

/// Geometry shared by the drag feedback and the board hit-testing.
///
/// The feedback is drawn at board scale, lifted above the finger so it stays
/// visible. Flutter hit-tests drag targets at `pointer + feedbackOffset`; we
/// aim that point at the centre of the shape's top-left (origin) cell, so the
/// board cell receiving the hover *is* the placement origin.
abstract final class TrayDragGeometry {
  static double lift(double cellSize) => cellSize * 1.4;

  static Size feedbackSize(PuzzleShape shape, double cellSize) =>
      Size(shape.colCount * cellSize, shape.rowCount * cellSize);

  /// Point inside the feedback that sits under the pointer.
  static Offset anchor(PuzzleShape shape, double cellSize) {
    final s = feedbackSize(shape, cellSize);
    return Offset(s.width / 2, s.height + lift(cellSize));
  }

  static Offset feedbackOffset(PuzzleShape shape, double cellSize) =>
      Offset(cellSize / 2, cellSize / 2) - anchor(shape, cellSize);
}

/// Bottom tray with three fixed slots. A shape keeps its slot until placed,
/// so remaining pieces don't jump sideways.
class ShapeTray extends StatefulWidget {
  const ShapeTray({
    super.key,
    required this.width,
    required this.height,
    required this.boardCellSize,
  });

  final double width;
  final double height;
  final double boardCellSize;

  static const int slotCount = 3;

  @override
  State<ShapeTray> createState() => _ShapeTrayState();
}

class _ShapeTrayState extends State<ShapeTray> {
  List<String?> _slots = List.filled(ShapeTray.slotCount, null);

  List<String?> _resolveSlots(List<PuzzleShape> tray) {
    final ids = [for (final s in tray) s.id];
    final allKnown = ids.every(_slots.contains);
    if (!allKnown) {
      // A fresh tray was dealt.
      return [
        for (var i = 0; i < ShapeTray.slotCount; i++)
          i < ids.length ? ids[i] : null,
      ];
    }
    return [for (final id in _slots) ids.contains(id) ? id : null];
  }

  @override
  Widget build(BuildContext context) {
    const border = 1.0;
    final slotWidth = max(0.0, widget.width - 2 * border) / ShapeTray.slotCount;
    final innerHeight = max(0.0, widget.height - 2 * border);
    // Largest catalog shape is 4 wide × 3 tall.
    final trayCell = [
      slotWidth * 0.8 / 4,
      innerHeight * 0.78 / 3,
      widget.boardCellSize * 0.62,
    ].reduce(min);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: VoltColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VoltColors.panelBorder, width: border),
      ),
      child: BlocBuilder<GameBloc, GameState>(
        buildWhen: (p, c) =>
            p.trayShapes != c.trayShapes || p.isGameOver != c.isGameOver,
        builder: (context, state) {
          _slots = _resolveSlots(state.trayShapes);
          final byId = {for (final s in state.trayShapes) s.id: s};
          return Row(
            children: [
              for (final id in _slots)
                Expanded(
                  child: byId[id] == null
                      ? const SizedBox.expand()
                      : TraySlot(
                          key: ValueKey<String>(id!),
                          shape: byId[id]!,
                          trayCellSize: trayCell,
                          boardCellSize: widget.boardCellSize,
                          enabled: !state.isGameOver,
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One draggable tray piece. If the drop is rejected or lands off the board,
/// the piece flies back from where it was released into its slot.
class TraySlot extends StatefulWidget {
  const TraySlot({
    super.key,
    required this.shape,
    required this.trayCellSize,
    required this.boardCellSize,
    required this.enabled,
  });

  final PuzzleShape shape;
  final double trayCellSize;
  final double boardCellSize;
  final bool enabled;

  @override
  State<TraySlot> createState() => _TraySlotState();
}

class _TraySlotState extends State<TraySlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _return;
  OverlayEntry? _flight;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    _return = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _removeFlight();
    _return.dispose();
    super.dispose();
  }

  void _removeFlight() {
    _flight?.remove();
    _flight?.dispose();
    _flight = null;
  }

  void _animateBack(Velocity _, Offset releaseTopLeft) {
    final slotBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (slotBox == null || overlay == null || overlayBox == null) return;

    final restSize = TrayDragGeometry.feedbackSize(
      widget.shape,
      widget.trayCellSize,
    );
    final restTopLeft = slotBox.localToGlobal(
      slotBox.size.center(Offset.zero) - restSize.center(Offset.zero),
    );
    final from = overlayBox.globalToLocal(releaseTopLeft);
    final to = overlayBox.globalToLocal(restTopLeft);

    _removeFlight();
    final curve = CurvedAnimation(parent: _return, curve: Curves.easeOutCubic);
    _flight = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: curve,
        builder: (_, _) {
          final t = curve.value;
          final pos = Offset.lerp(from, to, t)!;
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: IgnorePointer(
              child: ShapeView(
                shape: widget.shape,
                cellSize: lerpDouble(
                  widget.boardCellSize,
                  widget.trayCellSize,
                  t,
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(_flight!);
    setState(() => _returning = true);
    _return.forward(from: 0).whenComplete(() {
      _removeFlight();
      if (mounted) setState(() => _returning = false);
    });
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final shape = widget.shape;
    final board = widget.boardCellSize;
    final resting = ShapeView(shape: shape, cellSize: widget.trayCellSize);

    // The whole slot is the grab area (not just the piece's filled cells), so
    // small pieces are easy to pick up with a thumb.
    return SizedBox.expand(
      child: Draggable<PuzzleShape>(
        hitTestBehavior: HitTestBehavior.opaque,
        data: shape,
        maxSimultaneousDrags: widget.enabled && !_returning ? 1 : 0,
        dragAnchorStrategy: (_, _, _) => TrayDragGeometry.anchor(shape, board),
        feedbackOffset: TrayDragGeometry.feedbackOffset(shape, board),
        feedback: Material(
          type: MaterialType.transparency,
          child: ShapeView(shape: shape, cellSize: board),
        ),
        childWhenDragging: Center(
          child: Opacity(opacity: 0.15, child: resting),
        ),
        onDragStarted: HapticFeedback.selectionClick,
        onDraggableCanceled: _animateBack,
        child: Center(
          child: Opacity(opacity: _returning ? 0 : 1, child: resting),
        ),
      ),
    );
  }
}
