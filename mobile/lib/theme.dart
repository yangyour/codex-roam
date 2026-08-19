import 'package:flutter/material.dart';

const canvas = Color(0xFFF5F6F8);
const panel = Color(0xFFFFFFFF);
const panelRaised = Color(0xFFEEF1F3);
const line = Color(0xFFDCE1E5);
const ink = Color(0xFF151A1F);
const muted = Color(0xFF67717A);
const mint = Color(0xFF0F8B6D);
const mintSoft = Color(0xFFE3F3EE);
const danger = Color(0xFFC84C4C);
const dangerSoft = Color(0xFFFBEAEA);
const commandSurface = Color(0xFF182028);
const commandText = Color(0xFFE8EDF1);

ThemeData get codexTheme {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.light,
      ).copyWith(
        surface: panel,
        surfaceContainer: panel,
        surfaceContainerHigh: panelRaised,
        primary: mint,
        onPrimary: Colors.white,
        onSurface: ink,
        outline: line,
        error: danger,
      );

  return ThemeData(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    useMaterial3: true,
    fontFamily: 'sans-serif',
    appBarTheme: const AppBarTheme(
      backgroundColor: panel,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      hintStyle: const TextStyle(color: muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: mint),
      ),
    ),
  );
}
