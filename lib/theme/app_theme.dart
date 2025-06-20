import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color surfaceColor = Color(0xFF2C2C2E);
  static const Color backgroundColor = Color(0xFF1C1C1E);
  static const Color accentColor = Color(0xFF9D8DFF);
  static const Color errorColor = Color(0xFFFF6B6B);

  static const cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.all(Radius.circular(16)),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14,
    color: Colors.white70,
  );
}
