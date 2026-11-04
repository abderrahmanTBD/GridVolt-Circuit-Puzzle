import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/game/game_bloc.dart';
import '../../application/settings/audio_settings_cubit.dart';
import '../effects/sound_effects.dart';
import '../widgets/game_board.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/placement_preview.dart';
import '../widgets/shape_tray.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  /// Delay before the Game Over card, so the final line-clear can play out.
  static const gameOverDelay = Duration(milliseconds: 700);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PlacementPreviewController _preview = PlacementPreviewController(null);

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  void _play(Sfx sfx) {
    if (context.read<AudioSettingsCubit>().state) return;
    context.read<SoundEffects>().play(sfx);
  }

  void _onMove(GameState state) {
    final r = state.lastMoveResult!;
    if (r.batterySurgeCount > 0) {
      _play(Sfx.surge);
      HapticFeedback.heavyImpact();
    } else if (r.clearedLinesCount > 0) {
      _play(Sfx.clear);
      HapticFeedback.mediumImpact();
    } else {
      _play(Sfx.drop);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _onGameOver() async {
    _play(Sfx.gameOver);
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(GameScreen.gameOverDelay);
    if (!mounted) return;
    final bloc = context.read<GameBloc>();
    final s = bloc.state;
    if (!s.isGameOver) return;
    await GameOverDialog.show(
      context,
      score: s.currentScore,
      highScore: s.highScore,
      isNewHighScore: s.isNewHighScore,
      onReplay: () => bloc.add(const StartNewGame()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GameBloc, GameState>(
          listenWhen: (p, c) =>
              p.lastMoveResult != c.lastMoveResult && c.lastMoveResult != null,
          listener: (_, s) => _onMove(s),
        ),
        BlocListener<GameBloc, GameState>(
          listenWhen: (p, c) => !p.isGameOver && c.isGameOver,
          listener: (_, _) => _onGameOver(),
        ),
      ],
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [Color(0xFF0D1830), Color(0xFF060A12)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => _ResponsiveLayout(
                constraints: constraints,
                preview: _preview,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sizes the HUD, board and tray from the available space. Portrait stacks
/// them vertically; wide screens put the board left and HUD + tray right.
/// Every dimension is derived from the constraints, so nothing can overflow.
class _ResponsiveLayout extends StatelessWidget {
  const _ResponsiveLayout({required this.constraints, required this.preview});

  final BoxConstraints constraints;
  final PlacementPreviewController preview;

  static const gutter = 16.0;
  static const gap = 12.0;
  static const maxBoard = 680.0;

  @override
  Widget build(BuildContext context) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final landscape = w > h * 1.2;

    if (!landscape) {
      final hud = (h * 0.1).clamp(44.0, 84.0);
      final tray = (h * 0.19).clamp(72.0, 170.0);
      final board = min(
        w - 2 * gutter,
        h - hud - tray - 3 * gap,
      ).clamp(0.0, maxBoard);
      final sideWidth = min(w - 2 * gutter, max(board, 560.0));
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: sideWidth,
              child: GameHud(height: hud),
            ),
            const SizedBox(height: gap),
            GameBoard(size: board, preview: preview),
            const SizedBox(height: gap),
            ShapeTray(
              width: sideWidth,
              height: tray,
              boardCellSize: GameBoard.cellSizeFor(board),
            ),
          ],
        ),
      );
    }

    final board = min(h - 2 * gap, w * 0.6 - gutter).clamp(0.0, maxBoard);
    final panel = max(0.0, w - board - 3 * gutter);
    final hud = (h * 0.16).clamp(44.0, 84.0);
    final tray = max(0.0, min(max(h * 0.4, 80.0), h - hud - 3 * gap));
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameBoard(size: board, preview: preview),
          const SizedBox(width: gutter),
          SizedBox(
            width: panel,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameHud(height: hud),
                const SizedBox(height: gap),
                ShapeTray(
                  width: panel,
                  height: tray,
                  boardCellSize: GameBoard.cellSizeFor(board),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
