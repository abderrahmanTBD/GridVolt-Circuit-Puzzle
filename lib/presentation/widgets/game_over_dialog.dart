import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/volt_theme.dart';

/// Frosted-glass Game Over card with final score, best score and Replay.
class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.score,
    required this.highScore,
    required this.isNewHighScore,
    required this.onReplay,
  });

  final int score;
  final int highScore;
  final bool isNewHighScore;
  final VoidCallback onReplay;

  static Future<void> show(
    BuildContext context, {
    required int score,
    required int highScore,
    required bool isNewHighScore,
    required VoidCallback onReplay,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Game over',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (dialogContext, _, _) => PopScope(
        canPop: false,
        child: GameOverDialog(
          score: score,
          highScore: highScore,
          isNewHighScore: isNewHighScore,
          onReplay: () {
            Navigator.of(dialogContext).pop();
            onReplay();
          },
        ),
      ),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: VoltColors.surface.withValues(alpha: 0.62),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: VoltColors.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.power_off_rounded,
                        size: 44,
                        color: VoltColors.danger,
                        shadows: [
                          Shadow(color: VoltColors.danger, blurRadius: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CIRCUIT OVERLOAD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'No more pieces fit the grid.',
                        style: TextStyle(color: VoltColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'FINAL SCORE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2.5,
                          color: VoltColors.textMuted,
                        ),
                      ),
                      Text(
                        '$score',
                        key: const Key('game-over-score'),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: [
                            Shadow(color: VoltColors.accent, blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isNewHighScore)
                        const _NewRecordChip()
                      else
                        Text(
                          'Best  $highScore',
                          key: const Key('game-over-best'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: VoltColors.volt,
                          ),
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onReplay,
                          style: FilledButton.styleFrom(
                            backgroundColor: VoltColors.accent,
                            foregroundColor: VoltColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('REPLAY'),
                        ),
                      ),
                    ],
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

class _NewRecordChip extends StatelessWidget {
  const _NewRecordChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: VoltColors.volt.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoltColors.volt),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 18, color: VoltColors.volt),
          SizedBox(width: 6),
          Text(
            'NEW HIGH SCORE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: VoltColors.volt,
            ),
          ),
        ],
      ),
    );
  }
}
