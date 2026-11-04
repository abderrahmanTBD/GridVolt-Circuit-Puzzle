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

/// Lets the game start immediately while sounds load in the background.
/// Effects requested before loading finishes are skipped (only the first
/// moments after launch are affected).
class DeferredSoundEffects implements SoundEffects {
  DeferredSoundEffects(Future<SoundEffects> loading) {
    loading.then((s) {
      if (_disposed) {
        s.dispose();
      } else {
        _inner = s;
      }
    });
  }

  SoundEffects? _inner;
  bool _disposed = false;

  @override
  void play(Sfx sfx) => _inner?.play(sfx);

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _inner?.dispose();
  }
}

/// Low-latency playback of the bundled WAVs (see `tool/generate_sounds.dart`).
/// Mixes with the user's music instead of pausing it, and respects the iOS
/// silent switch.
///
/// Uses a small round-robin set of preloaded players per sound, so rapid
/// repeats overlap instead of cutting each other off. Each player's position
/// updater is disabled: audioplayers otherwise schedules a frame callback on
/// every frame until it hears that playback completed, and low-latency
/// (SoundPool) playback on Android never reports completion — that would keep
/// the app rendering at full frame rate forever, draining the battery.
class AudioPlayersSoundEffects implements SoundEffects {
  AudioPlayersSoundEffects._(this._players);

  final Map<Sfx, List<AudioPlayer>> _players;
  final Map<Sfx, int> _next = {};

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

  static int _voices(Sfx sfx) => sfx == Sfx.drop ? 3 : 2;

  /// Preloads every sound. Falls back to [SilentSoundEffects] if the platform
  /// audio backend is unavailable, so audio can never crash the game.
  static Future<SoundEffects> create() async {
    final created = <AudioPlayer>[];
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      final players = <Sfx, List<AudioPlayer>>{};
      for (final MapEntry(key: sfx, value: path) in _assets.entries) {
        // Load all voices in parallel; sequential loading delayed startup.
        players[sfx] = await Future.wait([
          for (var i = 0; i < _voices(sfx); i++)
            _preload(path, _volume[sfx]!, created),
        ]);
      }
      return AudioPlayersSoundEffects._(players);
    } catch (error) {
      debugPrint('GridVolt audio disabled: $error');
      for (final p in created) {
        unawaited(p.dispose());
      }
      return const SilentSoundEffects();
    }
  }

  static Future<AudioPlayer> _preload(
    String path,
    double volume,
    List<AudioPlayer> created,
  ) async {
    final player = AudioPlayer()..positionUpdater = null;
    created.add(player);
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(volume);
    await player.setSource(AssetSource(path));
    return player;
  }

  @override
  void play(Sfx sfx) {
    final voices = _players[sfx];
    if (voices == null || voices.isEmpty) return;
    final i = _next[sfx] ?? 0;
    _next[sfx] = (i + 1) % voices.length;
    final player = voices[i];
    unawaited(() async {
      try {
        await player.stop();
        await player.resume();
      } catch (e) {
        debugPrint('SFX $sfx failed: $e');
      }
    }());
  }

  @override
  Future<void> dispose() async {
    for (final voices in _players.values) {
      for (final p in voices) {
        await p.dispose();
      }
    }
  }
}
