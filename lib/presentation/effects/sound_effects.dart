import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { drop, clear, surge, gameOver }

/// Fire-and-forget sound triggers. Injected so widget tests can run silently.
abstract interface class SoundEffects {
  void play(Sfx sfx);
  Future<void> dispose();
}

class SilentSoundEffects implements SoundEffects {
  const SilentSoundEffects();

  @override
  void play(Sfx sfx) {}

  @override
  Future<void> dispose() async {}
}

/// Low-latency pooled playback of the bundled WAVs (see
/// `tool/generate_sounds.dart`). Mixes with the user's music instead of
/// pausing it, and respects the iOS silent switch.
class AudioPlayersSoundEffects implements SoundEffects {
  AudioPlayersSoundEffects._(this._pools);

  final Map<Sfx, AudioPool> _pools;

  static const _assets = {
    Sfx.drop: 'sounds/drop.wav',
    Sfx.clear: 'sounds/clear.wav',
    Sfx.surge: 'sounds/surge.wav',
    Sfx.gameOver: 'sounds/game_over.wav',
  };

  static const _volume = {
    Sfx.drop: 0.55,
    Sfx.clear: 0.8,
    Sfx.surge: 1.0,
    Sfx.gameOver: 0.8,
  };

  /// Preloads every sound. Falls back to [SilentSoundEffects] if the platform
  /// audio backend is unavailable, so audio can never crash the game.
  static Future<SoundEffects> create() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      final pools = <Sfx, AudioPool>{};
      for (final MapEntry(key: sfx, value: path) in _assets.entries) {
        pools[sfx] = await AudioPool.createFromAsset(
          path: path,
          maxPlayers: sfx == Sfx.drop ? 4 : 2,
          playerMode: PlayerMode.lowLatency,
        );
      }
      return AudioPlayersSoundEffects._(pools);
    } catch (error) {
      debugPrint('GridVolt audio disabled: $error');
      return const SilentSoundEffects();
    }
  }

  @override
  void play(Sfx sfx) {
    final pool = _pools[sfx];
    if (pool == null) return;
    unawaited(
      pool
          .start(volume: _volume[sfx]!)
          .then(
            (_) {},
            onError: (Object e) => debugPrint('SFX $sfx failed: $e'),
          ),
    );
  }

  @override
  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
  }
}
