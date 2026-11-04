import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in `test/`.
///
/// Golden images are rendered on Windows locally and Linux in CI, and
/// anti-aliasing differs slightly between them. Goldens use the default test
/// font (glyphs render as boxes, identically everywhere) and this comparator
/// accepts up to [_tolerance] of differing pixels, so real visual changes
/// fail but OS rasterisation noise does not.
const double _tolerance = 0.015; // 1.5 %

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      current.basedir.resolve('golden_test.dart'),
    );
  }
  await testMain();
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
