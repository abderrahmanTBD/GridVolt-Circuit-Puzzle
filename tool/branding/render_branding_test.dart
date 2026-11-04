// Renders the app icon and splash artwork from the game's own widgets.
//
//   flutter test tool/branding
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Output: assets/branding/*.png (inputs for the two generators above).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:grid_volt/domain/models/models.dart';
import 'package:grid_volt/presentation/theme/volt_theme.dart';
import 'package:grid_volt/presentation/widgets/volt_cell.dart';

import '../test_fonts.dart';

const _key = Key('art');
final _out = Directory('assets/branding');

/// 2×2 grid of powered panels with a glowing bolt across it. [size] is the
/// width of the whole mark.
class _Mark extends StatelessWidget {
  const _Mark({required this.size, this.monochrome = false});

  final double size;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final cell = size * 0.46;
    final gap = size * 0.08;
    const colors = [1, 2, 3, 4]; // cyan, yellow, magenta, green
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!monochrome)
            for (var i = 0; i < 4; i++)
              Positioned(
                left: (i % 2) * (cell + gap),
                top: (i ~/ 2) * (cell + gap),
                child: Opacity(
                  opacity: 0.9,
                  child: VoltCell(
                    cell: GridCell(colorId: colors[i]),
                    size: cell,
                  ),
                ),
              ),
          Icon(
            Icons.electric_bolt_rounded,
            size: size * (monochrome ? 1.0 : 0.82),
            color: monochrome ? Colors.white : Colors.white,
            shadows: monochrome
                ? null
                : [
                    Shadow(color: VoltColors.volt, blurRadius: size * 0.06),
                    Shadow(color: VoltColors.volt, blurRadius: size * 0.02),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: size * 0.03,
                      offset: Offset(0, size * 0.01),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

Future<void> _render(
  WidgetTester tester, {
  required String name,
  required Object canvas, // double (square) or Size
  bool opaque = false,
  String? dir,
  required Widget child,
  Decoration? background,
}) async {
  final size = canvas is Size ? canvas : Size.square(canvas as double);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: _key,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: background,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      if (!opaque) {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }
      // Play Store graphics must be 24-bit PNG (no alpha channel).
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: raw!.buffer,
        numChannels: 4,
      );
      return img.encodePng(rgba.convert(numChannels: 3));
    } finally {
      image.dispose();
    }
  });
  final out = Directory(dir ?? _out.path)..createSync(recursive: true);
  File('${out.path}/$name.png').writeAsBytesSync(png!);
}

const _iconBackground = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -0.2),
    radius: 0.9,
    colors: [Color(0xFF13234A), VoltColors.background],
  ),
);

void main() {
  setUpAll(loadRealFonts);

  // iOS and legacy Android: full-bleed, opaque (iOS rejects transparency).
  testWidgets('icon', (tester) async {
    await _render(
      tester,
      name: 'icon',
      canvas: 1024.0,
      background: _iconBackground,
      child: const _Mark(size: 640),
    );
  });

  // Android adaptive icon foreground: the launcher masks a 108dp square to
  // any shape and only guarantees the central 66dp, so the mark stays inside.
  testWidgets('adaptive foreground', (tester) async {
    await _render(
      tester,
      name: 'icon_foreground',
      canvas: 1024.0,
      child: const _Mark(size: 540),
    );
  });

  // Android 13+ themed icon: a single-color silhouette the system tints.
  testWidgets('monochrome', (tester) async {
    await _render(
      tester,
      name: 'icon_monochrome',
      canvas: 1024.0,
      child: const _Mark(size: 520, monochrome: true),
    );
  });

  // Google Play listing: 512×512 hi-res icon.
  testWidgets('store icon', (tester) async {
    await _render(
      tester,
      name: 'icon_512',
      canvas: 512.0,
      dir: 'docs/store',
      background: _iconBackground,
      child: const _Mark(size: 320),
    );
  });

  // Google Play listing: 1024×500 feature graphic, 24-bit.
  testWidgets('feature graphic', (tester) async {
    await _render(
      tester,
      name: 'feature_graphic',
      canvas: const Size(1024, 500),
      dir: 'docs/store',
      opaque: true,
      background: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.45, 0),
          radius: 1.3,
          colors: [Color(0xFF13234A), VoltColors.background],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Mark(size: 270),
          SizedBox(width: 56),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRIDVOLT',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 92,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: VoltColors.accent,
                  shadows: [Shadow(color: VoltColors.accent, blurRadius: 24)],
                ),
              ),
              Text(
                'CIRCUIT PUZZLE',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                  color: VoltColors.textPrimary,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Power the grid. Clear the lines.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  color: VoltColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });

  // Android 12+ splash: 1152 canvas, icon must fit a 768 circle.
  testWidgets('splash', (tester) async {
    await _render(
      tester,
      name: 'splash_logo',
      canvas: 1152.0,
      child: const _Mark(size: 520),
    );
  });
}
