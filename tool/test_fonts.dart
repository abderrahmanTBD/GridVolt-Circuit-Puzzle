import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto and Material Icons from the Flutter SDK so widget renders in
/// `flutter test` show real text instead of the test font's boxes.
Future<void> loadRealFonts() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final fonts = Directory('${artifacts.path}/material_fonts');
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(read('roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('materialicons-regular.otf'))).load();
}
