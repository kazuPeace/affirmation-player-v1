import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF5ED0B4);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme.copyWith(
      surface: const Color(0xFF11151F),
      surfaceContainerHighest: const Color(0xFF222A38),
      primary: const Color(0xFF69E2C4),
      secondary: const Color(0xFFFFC982),
    ),
    scaffoldBackgroundColor: const Color(0xFF090C13),
    cardColor: const Color(0xFF151B26),
    dividerColor: Colors.white12,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF171F2D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF69E2C4)),
      ),
    ),
    sliderTheme: const SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1A2130),
      selectedColor: const Color(0xFF24423A),
      side: BorderSide.none,
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
