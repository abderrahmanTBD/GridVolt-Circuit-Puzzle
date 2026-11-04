import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../domain/models/models.dart';

class OnboardingState extends Equatable {
  const OnboardingState({this.tutorialSeen = false, this.hintsSeen = const {}});

  final bool tutorialSeen;

  /// Special tiles whose "what is this?" hint has already been shown.
  final Set<SpecialTile> hintsSeen;

  bool hasSeenHint(SpecialTile tile) => hintsSeen.contains(tile);

  @override
  List<Object?> get props => [tutorialSeen, hintsSeen];
}

/// Persisted first-run state: the tutorial, plus a one-time hint the first
/// time each special tile shows up in the tray.
class OnboardingCubit extends HydratedCubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingState());

  /// [finished] is true when the player read every step (which explains the
  /// special tiles, so their hints are no longer needed) and false on Skip.
  void completeTutorial({required bool finished}) => emit(
    OnboardingState(
      tutorialSeen: true,
      hintsSeen: finished
          ? {SpecialTile.battery, SpecialTile.multiplier}
          : state.hintsSeen,
    ),
  );

  void markHintSeen(SpecialTile tile) => emit(
    OnboardingState(
      tutorialSeen: state.tutorialSeen,
      hintsSeen: {...state.hintsSeen, tile},
    ),
  );

  @override
  OnboardingState? fromJson(Map<String, dynamic> json) {
    final hints = json['hintsSeen'];
    return OnboardingState(
      tutorialSeen: json['tutorialSeen'] == true,
      hintsSeen: {
        if (hints is List)
          for (final h in hints)
            for (final t in SpecialTile.values)
              if (t.name == h) t,
      },
    );
  }

  @override
  Map<String, dynamic>? toJson(OnboardingState state) => {
    'tutorialSeen': state.tutorialSeen,
    'hintsSeen': [for (final t in state.hintsSeen) t.name],
  };
}
