import 'package:flutter/material.dart';

abstract final class VoltColors {
  static const background = Color(0xFF060A12);
  static const surface = Color(0xFF0C121E);
  static const panel = Color(0xFF0D1320);
  static const panelBorder = Color(0xFF1A2436);
  static const boardFrame = Color(0xFF090E18);
  static const accent = Color(0xFF00E5FF);
  static const volt = Color(0xFFFFD600);
  static const danger = Color(0xFFFF1744);
  static const textPrimary = Color(0xFFE8F1FF);
  static const textMuted = Color(0xFF7D8BA6);
}

abstract final class VoltTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VoltColors.background,
      colorScheme: const ColorScheme.dark(
        primary: VoltColors.accent,
        secondary: VoltColors.volt,
        surface: VoltColors.surface,
        error: VoltColors.danger,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: VoltColors.textPrimary,
        displayColor: VoltColors.textPrimary,
      ),
    );
  }
}
