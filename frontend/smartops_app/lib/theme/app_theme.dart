import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFFFF8FC);
  static const Color primary = Color(0xFFF4A6C1);
  static const Color secondary = Color(0xFFC8B6FF);
  static const Color accent = Color(0xFFFF4F9A);
  static const Color text = Color(0xFF211B24);
  static const Color success = Color(0xFF62C6A0);
  static const Color warning = Color(0xFFF4B860);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ),
    fontFamily: 'Arial',
  );
}