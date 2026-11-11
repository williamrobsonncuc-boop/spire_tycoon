import 'package:flutter/material.dart';

// Style guide colors. Named once so every screen uses the same palette.
const Color navy = Color(0xFF1E293B);
const Color slate = Color(0xFF334155);
const Color cream = Color(0xFFF8FAFC);
const Color cyan = Color(0xFF06B6D4);
const Color emerald = Color(0xFF10B981);
const Color crimson = Color(0xFFEF4444);

/// Darker than navy, for notes that sit on a tinted tower.
const Color ink = Color(0xFF0F172A);

const double cornerRadius = 12;

/// How wide the game column gets on a desktop window.
const double pageMaxWidth = 840;

/// Dark theme using the bundled Inter font.
ThemeData buildAppTheme() {
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerRadius),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      surface: navy,
      primary: emerald,
      onPrimary: cream,
      secondary: cyan,
      onSurface: cream,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: cream,
      displayColor: cream,
      fontFamily: 'Inter',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: cream,
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: DialogThemeData(backgroundColor: slate, shape: shape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: emerald,
        foregroundColor: cream,
        disabledBackgroundColor: slate,
        disabledForegroundColor: cream.withValues(alpha: 0.55),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Color(0x2EF8FAFC))),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cream,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Color(0x2906B6D4))),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: cream,
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Color(0x2906B6D4))),
    ),
  );
}
