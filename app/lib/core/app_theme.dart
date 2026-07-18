import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2D6A4F),
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
