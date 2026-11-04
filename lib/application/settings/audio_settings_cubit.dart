import 'package:hydrated_bloc/hydrated_bloc.dart';

/// Persisted mute toggle. State is `true` when sound is muted.
class AudioSettingsCubit extends HydratedCubit<bool> {
  AudioSettingsCubit() : super(false);

  void toggleMute() => emit(!state);

  @override
  bool? fromJson(Map<String, dynamic> json) => json['muted'] as bool? ?? false;

  @override
  Map<String, dynamic>? toJson(bool state) => {'muted': state};
}
