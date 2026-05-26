import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryStart = Color(0xFF06B6D4);
  static const Color primaryEnd = Color(0xFF10B981);
  static const Color cardBg = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFF64748B);

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [primaryStart, primaryEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static TextStyle heading(double size) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
      );

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );
}
