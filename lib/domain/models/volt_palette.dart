/// Neon colors for shape color ids, as ARGB ints so the domain layer stays
/// free of Flutter imports. Color id 0 is reserved for empty cells.
abstract final class VoltPalette {
  static const List<int> _hex = [
    0xFF1A2233, // 0: empty (unused for shapes)
    0xFF00E5FF, // 1: cyan
    0xFFFFD600, // 2: volt yellow
    0xFFFF3D9A, // 3: magenta
    0xFF76FF03, // 4: green
    0xFFFF9100, // 5: orange
    0xFFB388FF, // 6: violet
  ];

  static int get shapeColorCount => _hex.length - 1;

  static int colorHex(int colorId) => _hex[colorId % _hex.length];
}
