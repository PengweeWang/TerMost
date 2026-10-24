import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppTheme {
  static const Color primarySeed = Color(0xFF0284C7); // Sky / Tech Blue

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardTheme(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF1E293B), // Slate 800
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 0.5),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }

  // MD3 Terminal Theme for xterm
  static const TerminalTheme terminalDarkTheme = TerminalTheme(
    cursor: Color(0xFF38BDF8),
    selection: Color(0x4038BDF8),
    foreground: Color(0xFFE2E8F0),
    background: Color(0xFF0F172A),
    black: Color(0xFF1E293B),
    red: Color(0xFFEF4444),
    green: Color(0xFF22C55E),
    yellow: Color(0xFFEAB308),
    blue: Color(0xFF3B82F6),
    magenta: Color(0xFFA855F7),
    cyan: Color(0xFF06B6D4),
    white: Color(0xFFF8FAFC),
    brightBlack: Color(0xFF64748B),
    brightRed: Color(0xFFF87171),
    brightGreen: Color(0xFF4ADE80),
    brightYellow: Color(0xFFFDE047),
    brightBlue: Color(0xFF60A5FA),
    brightMagenta: Color(0xFFC084FC),
    brightCyan: Color(0xFF22D3EE),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFEAB308),
    searchHitBackgroundCurrent: Color(0xFFF97316),
    searchHitForeground: Color(0xFF000000),
  );
}
