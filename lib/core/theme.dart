import 'package:flutter/material.dart';

abstract final class JuriTheme {
  static const background = Color(0xFF101211),
      surface = Color(0xFF1B1E1C),
      elevated = Color(0xFF252924),
      ink = Color(0xFFF4F2E8),
      muted = Color(0xFF92978F),
      gold = Color(0xFFDCC58C),
      line = Color(0xFF30352F);
  static Color clubColor(String id) => switch (id) {
    '3604' => const Color(0xFFE8AF56),
    '3592' => const Color(0xFFE7D56E),
    '3590' => const Color(0xFFE1E2E0),
    '3596' => const Color(0xFF8AC2D2),
    '3678' => const Color(0xFF81AE8B),
    '3631' => const Color(0xFF72ADA0),
    '3688' => const Color(0xFFE7AD61),
    _ => gold,
  };
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    fontFamily: 'Manrope',
    colorScheme: const ColorScheme.dark(
      primary: gold,
      onPrimary: background,
      surface: surface,
      onSurface: ink,
      secondary: gold,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, fontSize: 14),
      bodySmall: TextStyle(color: muted, fontSize: 12),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: line, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      dragHandleColor: muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: background,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: gold,
      labelStyle: const TextStyle(fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 5,
      activeTrackColor: gold,
      thumbColor: gold,
      inactiveTrackColor: line,
      overlayColor: Color(0x22DCC58C),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: muted, fontSize: 13),
    ),
  );
}
