import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_volt/presentation/effects/sound_effects.dart';

class _Recording implements SoundEffects {
  final played = <Sfx>[];
  bool disposed = false;

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  test('skips sounds until loaded, then plays them', () async {
    final loading = Completer<SoundEffects>();
    final deferred = DeferredSoundEffects(loading.future);
    final inner = _Recording();

    deferred.play(Sfx.drop); // still loading: skipped, no error
    loading.complete(inner);
    await Future<void>.delayed(Duration.zero);
    deferred.play(Sfx.clear);

    expect(inner.played, [Sfx.clear]);
  });

  test('disposes sounds that finish loading after dispose', () async {
    final loading = Completer<SoundEffects>();
    final deferred = DeferredSoundEffects(loading.future);
    final inner = _Recording();

    await deferred.dispose();
    loading.complete(inner);
    await Future<void>.delayed(Duration.zero);

    expect(inner.disposed, isTrue);
  });
}
