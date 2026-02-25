// UYC - Unlock Your Cloud
// Color Scheme Definition

import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF1a6b8a); // Blue-green
  static const Color accent = Color(0xFFd98324); // Orange
  static const Color textLight = Color(0xFFf2e8cf); // Cream

  // Semantic Colors
  static const Color background = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Colors.grey;
  static const Color error = Color(0xFFd32f2f);
  static const Color success = Color(0xFF4caf50);

  // UI Element Colors
  static const Color border = Color(0xFFF0F0F0);
  static const Color shadow = Colors.black12;

  // Get MaterialColor swatch for theme
  static MaterialColor get primarySwatch {
    return MaterialColor(primary.toARGB32(), {
      50: Color(0xFFe3f2f7),
      100: Color(0xFFb8dfeb),
      200: Color(0xFF88cadf),
      300: Color(0xFF58b5d3),
      400: Color(0xFF34a5ca),
      500: primary,
      600: Color(0xFF17627f),
      700: Color(0xFF135775),
      800: Color(0xFF0f4d6b),
      900: Color(0xFF083c58),
    });
  }
}
