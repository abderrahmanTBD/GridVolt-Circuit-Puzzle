import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/game/game_bloc.dart';
import '../../application/onboarding/onboarding_cubit.dart';
import '../../application/settings/audio_settings_cubit.dart';
import '../../domain/models/models.dart';
import '../effects/sound_effects.dart';
import '../widgets/game_board.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/placement_preview.dart';
import '../widgets/shape_tray.dart';
import '../widgets/special_tile_hint.dart';
import '../widgets/tutorial_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  /// Delay before the Game Over card, so the final line-clear can play out.
  static const gameOverDelay = Duration(milliseconds: 700);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PlacementPreviewController _preview = PlacementPreviewController(null);
  late bool _showTutorial;
  SpecialTile? _hint;
  Timer? _hintTimer;

  static const _hintDuration = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _showTutorial = !context.read<OnboardingCubit>().state.tutorialSeen;
    // A restored run may already hold a special tile the player never saw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowHint(context.read<GameBloc>().state.trayShapes);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _preview.dispose();
    super.dispose();
  }

  void _closeTutorial({required bool finished}) {
    context.read<OnboardingCubit>().completeTutorial(finished: finished);
    setState(() => _showTutorial = false);
    _maybeShowHint(context.read<GameBloc>().state.trayShapes);
  }

  /// Shows the first-time explanation for a newly dealt special tile.
  void _maybeShowHint(List<PuzzleShape> tray) {
    if (_showTutorial || _hint != null) return;
    final onboarding = context.read<OnboardingCubit>();
    for (final shape in tray) {
      final tile = shape.special;
      if (tile != SpecialTile.none && !onboarding.state.hasSeenHint(tile)) {
        onboarding.markHintSeen(tile);
        setState(() => _hint = tile);
        _hintTimer?.cancel();
        _hintTimer = Timer(_hintDuration, _closeHint);
        return;
      }
    }
  }

  void _closeHint() {
    _hintTimer?.cancel();
    if (mounted) setState(() => _hint = null);
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
        BlocListener<GameBloc, GameState>(
          listenWhen: (p, c) => p.trayShapes != c.trayShapes,
          listener: (_, s) => _maybeShowHint(s.trayShapes),
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
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
                      onHelp: () => setState(() => _showTutorial = true),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, -0.4),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: _hint == null
                            ? const SizedBox.shrink()
                            : SpecialTileHint(
                                tile: _hint!,
                                onClose: _closeHint,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showTutorial)
              Positioned.fill(child: TutorialOverlay(onDone: _closeTutorial)),
          ],
        ),
      ),
    );
  }
}

/// Sizes the HUD, board and tray from the available space. Portrait stacks
/// them vertically; wide screens put the board left and HUD + tray right.
/// Every dimension is derived from the constraints, so nothing can overflow.
class _ResponsiveLayout extends StatelessWidget {
  const _ResponsiveLayout({
    required this.constraints,
    required this.preview,
    required this.onHelp,
  });

  final BoxConstraints constraints;
  final PlacementPreviewController preview;
  final VoidCallback onHelp;

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
      // Spread spare height evenly so tall phones don't bunch everything in
      // the middle. 3 * gap was reserved above, so spacing never collapses.
      return SizedBox(
        width: w,
        height: h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: sideWidth,
              child: GameHud(height: hud, onHelp: onHelp),
            ),
            GameBoard(size: board, preview: preview),
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
                GameHud(height: hud, onHelp: onHelp),
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
