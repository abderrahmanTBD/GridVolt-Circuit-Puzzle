import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/game/game_bloc.dart';
import '../../application/settings/audio_settings_cubit.dart';
import '../theme/volt_theme.dart';

/// Top bar: score, high score, logo and mute toggle. Everything sits in
/// FittedBoxes so it shrinks instead of overflowing on short screens.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.height, this.onHelp});

  final double height;

  /// Opens the how-to-play overlay; the button is hidden when null.
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: BlocBuilder<GameBloc, GameState>(
        buildWhen: (p, c) =>
            p.currentScore != c.currentScore || p.highScore != c.highScore,
        builder: (context, state) => Row(
          children: [
            Expanded(
              flex: 3,
              child: _ScoreBlock(
                label: 'SCORE',
                value: state.currentScore,
                color: VoltColors.accent,
                icon: Icons.bolt_rounded,
                valueKey: const Key('hud-score'),
              ),
            ),
            const Expanded(flex: 2, child: _Logo()),
            Expanded(
              flex: 3,
              child: _ScoreBlock(
                label: 'BEST',
                value: state.highScore,
                color: VoltColors.volt,
                icon: Icons.emoji_events_rounded,
                valueKey: const Key('hud-best'),
                alignEnd: true,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _MuteButton(),
                if (onHelp != null)
                  IconButton(
                    tooltip: 'How to play',
                    visualDensity: VisualDensity.compact,
                    onPressed: onHelp,
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: VoltColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.valueKey,
    this.alignEnd = false,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final Key valueKey;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                  color: VoltColors.textMuted,
                ),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              '${v.round()}',
              key: valueKey,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: VoltColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [Shadow(color: color, blurRadius: 14)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.electric_bolt_rounded,
            color: VoltColors.volt,
            size: 26,
            shadows: [Shadow(color: VoltColors.volt, blurRadius: 12)],
          ),
          Text(
            'GRIDVOLT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: VoltColors.accent,
              shadows: [Shadow(color: VoltColors.accent, blurRadius: 10)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context) {
    final muted = context.watch<AudioSettingsCubit>().state;
    return IconButton(
      tooltip: muted ? 'Unmute' : 'Mute',
      onPressed: context.read<AudioSettingsCubit>().toggleMute,
      icon: Icon(
        muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: muted ? VoltColors.textMuted : VoltColors.textPrimary,
      ),
    );
  }
}
