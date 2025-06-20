import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6AE0C8);
  static const secondary = Color(0xFF2C635B);
  static const background = Color(0xFF0D0F14);
  static const surface = Color(0xFF1C1F26); // Old surface color (consider renaming or removing if not needed)
  static const cardDark = Color(0xFF252932);
  static const error = Color(0xFFCF6679);
  static const white = Colors.white;
  static const textSecondaryOld = Color(0xFF9E9E9E);
  static const cardBorder = Color(0xFF2C2F38);
  static const cardBackground = Color(0xFF252932);
  static const onPrimary = Colors.white;
  static const Color cardLight = Color(0xFF2A2D3E);

  static final primaryGradient = LinearGradient(
    colors: [secondary.withOpacity(0.9), primary.withOpacity(0.9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color backgroundAlt = Color(0xFF1A1A2E); // Dark deep blue/purple
  static const Color surfaceAlt =
      Color(0xFF1F2947); // Slightly lighter dark blue for cards
  static const Color accent = Colors.tealAccent;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary =
      Color(0xFFa0a0d0); // Softer grey/lavender for secondary text
  static const Color green =
      Colors.greenAccent; // Brighter green for online status
  static const Color orange = Colors.orangeAccent;
  static const Color red = Colors.redAccent;
}
