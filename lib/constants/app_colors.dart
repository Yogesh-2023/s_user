import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF007BFF);
  static const Color fleetgoYellow = Color(0xFFFFC000);
  static const Color fleetgoYellowDark = Color(0xFFF4B41A);
  static const Color fleetgoTint = Color(0xFFFFF9E6);
  static const Color fleetgoSurface = Color(0xFFF7F7F8);
  static const Color secondary = Color(0xFF6C757D);
  static const Color background = Color(0xFFF8F9FA);
  static const Color lightBlueBackground = Color(0xFFE6F7FD);
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color error = Color(0xFFDC3545);

  // Auth Button Colors
  static const Color authButtonBackground = Color(0xFFF8F8F8);
  static const Color authButtonBorder = Color(0xF9F0F0F0);

  // TextField Colors
  static const Color textFieldBackground = Color(0xF8F8F8F8);

  // Gradient Colors
  static const Color gradientTop = Color(
    0xFFE2F0FE,
  ); // Darkened slightly to make it more visible
  static const Color gradientBottom = Color(0xFFFFFFFF);

  // Reusable Gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientTop, gradientBottom],
    stops: [0.0, 0.9], // Pushed white even further down
  );
}
