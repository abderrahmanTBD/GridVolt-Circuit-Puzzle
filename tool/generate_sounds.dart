// Synthesises the game's sound effects into assets/sounds/*.wav.
//
//   dart run tool/generate_sounds.dart
//
// Everything is procedurally generated, so the repo ships no third-party audio
// and there is nothing to license.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;
final Random _rng = Random(7);

void main() {
  final dir = Directory('assets/sounds')..createSync(recursive: true);
  final sounds = <String, List<double>>{
    'drop': _drop(),
    'clear': _clear(),
    'surge': _surge(),
    'game_over': _gameOver(),
  };
  sounds.forEach((name, samples) {
    final file = File('${dir.path}/$name.wav')..writeAsBytesSync(_wav(samples));
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  });
}

int _n(double seconds) => (seconds * sampleRate).round();

/// Short percussive "clunk" of a panel locking into place.
List<double> _drop() {
  final n = _n(0.11);
  var phase = 0.0;
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final freq = 220 * exp(-t * 18) + 70;
    phase += 2 * pi * freq / sampleRate;
    final env = exp(-t * 38);
    final click = i < 60
        ? (_rng.nextDouble() * 2 - 1) * (1 - i / 60) * 0.4
        : 0.0;
    return (sin(phase) * env * 0.8) + click;
  });
}

/// Rising electric zap with a shimmering tail.
List<double> _clear() {
  final n = _n(0.42);
  var p1 = 0.0, p2 = 0.0;
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final f = 380 + 1500 * pow(t / 0.42, 0.6);
    p1 += 2 * pi * f / sampleRate;
    p2 += 2 * pi * (f * 1.503) / sampleRate;
    final env = min(1.0, t * 80) * exp(-t * 7);
    final saw = 2 * ((p1 / (2 * pi)) % 1.0) - 1;
    final shimmer = sin(p2) * (0.5 + 0.5 * sin(t * 2 * pi * 28));
    return (saw * 0.35 + shimmer * 0.4) * env;
  });
}

/// Low boom + crackling noise burst for a battery surge.
List<double> _surge() {
  final n = _n(0.75);
  var phase = 0.0, lp = 0.0;
  return List.generate(n, (i) {
    final t = i / sampleRate;
    phase += 2 * pi * (90 * exp(-t * 4) + 38) / sampleRate;
    final boom = sin(phase) * exp(-t * 5);
    final cutoff = 0.5 * exp(-t * 3) + 0.03;
    lp += cutoff * ((_rng.nextDouble() * 2 - 1) - lp);
    final crackle = _rng.nextDouble() < 0.004 * exp(-t * 2) ? 0.8 : 0.0;
    final noise = (lp * 1.6 + crackle) * exp(-t * 4.5);
    return boom * 0.75 + noise * 0.55;
  });
}

/// Three descending triangle tones: power-down.
List<double> _gameOver() {
  const notes = [440.0, 349.2, 261.6, 196.0];
  const noteLen = 0.24;
  final out = <double>[];
  var phase = 0.0;
  for (var k = 0; k < notes.length; k++) {
    final len = k == notes.length - 1 ? noteLen * 2.2 : noteLen;
    for (var i = 0; i < _n(len); i++) {
      final t = i / sampleRate;
      final f = notes[k] * (1 - 0.04 * t / len);
      phase += 2 * pi * f / sampleRate;
      final tri = 2 * (2 * ((phase / (2 * pi)) % 1.0) - 1).abs() - 1;
      final env =
          min(1.0, t * 200) * exp(-t * (k == notes.length - 1 ? 2.5 : 6));
      out.add(tri * env * 0.6);
    }
  }
  return out;
}

Uint8List _wav(List<double> samples) {
  final peak = samples.fold<double>(0, (m, s) => max(m, s.abs()));
  final gain = peak > 0 ? 0.89 / peak : 1.0;
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    // Short fade-out on the last 2ms to avoid a click.
    final fade = min(1.0, (samples.length - i) / 44);
    final v = (samples[i] * gain * fade).clamp(-1.0, 1.0);
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
