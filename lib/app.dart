import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'application/game/game_bloc.dart';
import 'application/onboarding/onboarding_cubit.dart';
import 'application/settings/audio_settings_cubit.dart';
import 'presentation/effects/sound_effects.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/theme/volt_theme.dart';

class GridVoltApp extends StatelessWidget {
  const GridVoltApp({super.key, required this.soundEffects, this.gameBloc});

  final SoundEffects soundEffects;

  /// Optional pre-built bloc (tests); otherwise the saved run is resumed.
  final GameBloc? gameBloc;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<SoundEffects>.value(
      value: soundEffects,
      child: MultiBlocProvider(
        providers: [
          if (gameBloc case final bloc?)
            BlocProvider<GameBloc>.value(value: bloc)
          else
            BlocProvider<GameBloc>(
              create: (_) => GameBloc()..add(const ResumeOrStartGame()),
            ),
          BlocProvider(create: (_) => AudioSettingsCubit()),
          BlocProvider(create: (_) => OnboardingCubit()),
        ],
        child: MaterialApp(
          title: 'GridVolt: Circuit Puzzle',
          debugShowCheckedModeBanner: false,
          theme: VoltTheme.dark(),
          home: const GameScreen(),
        ),
      ),
    );
  }
}
