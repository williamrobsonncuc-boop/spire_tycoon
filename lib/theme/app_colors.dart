import 'package:flutter/material.dart';

// Style guide colors. Named once so every screen uses the same palette.
const Color navy = Color(0xFF1E293B);
const Color slate = Color(0xFF334155);
const Color cream = Color(0xFFF8FAFC);
const Color cyan = Color(0xFF06B6D4);
const Color emerald = Color(0xFF10B981);
const Color crimson = Color(0xFFEF4444);

const double cornerRadius = 12;

/// Dark theme using the bundled Inter font.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(surface: navy, primary: emerald),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: cream, displayColor: cream),
  );
}
