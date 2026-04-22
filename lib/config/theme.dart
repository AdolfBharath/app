import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Admin Theme
// ─────────────────────────────────────────────
class LmsAdminTheme {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueLight = Color(0xFFDBEAFE);
  static const Color accentOrange = Color(0xFFFB923C);
  static const Color accentOrangeLight = Color(0xFFFFEDD5);
  static const Color coinGold = Color(0xFFFACC15);
  static const Color secondaryGreen = Color(0xFF10B981);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;

  static const Color textDark = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color statusActive = Color(0xFF10B981);
  static const Color statusActiveBg = Color(0xFFD1FAE5);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusErrorBg = Color(0xFFFEE2E2);

  static const double borderRadiusConfig = 18.0;

  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    );
    final scheme = baseScheme.copyWith(
      primary: primaryBlue,
      primaryContainer: primaryBlueLight,
      secondary: accentOrange,
      secondaryContainer: accentOrangeLight,
      tertiary: secondaryGreen,
      surface: surfaceWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusConfig),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 12)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 10),
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        titleLarge: GoogleFonts.poppins(
            color: textDark, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.poppins(
            color: textDark, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.poppins(color: textDark),
        bodyMedium: GoogleFonts.poppins(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    );
    final scheme = baseScheme.copyWith(
      primary: primaryBlue,
      secondary: accentOrange,
      tertiary: secondaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusConfig),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 18)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 16),
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
          .copyWith(
        titleLarge: GoogleFonts.poppins(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: GoogleFonts.poppins(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  static BoxDecoration get adminCardDecoration {
    return BoxDecoration(
      color: surfaceWhite,
      borderRadius: BorderRadius.circular(borderRadiusConfig),
      border: Border.all(color: Colors.black.withValues(alpha: 10), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 5),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: surfaceWhite.withValues(alpha: 217),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 153), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 8),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Student Theme  (Premium EdTech Palette)
// ─────────────────────────────────────────────
class LmsStudentTheme {
  // Clone Pale Background & Surface
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface    = Color(0xFFFFFFFF);
  
  static const Color darkBackground  = Color(0xFF111827); // Standard dark equivalent
  static const Color darkSurface     = Color(0xFF1F2937);

  // Text Colors
  static const Color textPrimary   = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);

  // Theme Core
  static const Color primaryBlue   = Color(0xFF2563EB); // For tabs, buttons (as seen in image)
  static const Color customBlueGradientStart = Color(0xFF4F46E5);
  static const Color customBlueGradientEnd   = Color(0xFF7C3AED);

  // Accents
  static const Color accentOrange = Color(0xFFFF8A00); // Streak/Fire
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentCyan   = Color(0xFF22D3EE);

  static const List<Color> heroGradient = [
    customBlueGradientStart,
    customBlueGradientEnd,
  ];

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    );

    final scheme = baseScheme.copyWith(
      primary: primaryBlue,
      secondary: accentOrange,
      tertiary: accentPurple,
      surface: lightSurface,
      onSurface: textPrimary,
      onPrimary: Colors.white,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(displayColor: textPrimary, bodyColor: textPrimary)
        .copyWith(
          displayLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
          titleLarge: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
          titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.2),
          titleSmall: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
          bodyLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
          bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
          labelLarge: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
          labelMedium: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w500, color: textSecondary),
          labelSmall: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w500, color: textMuted),
        );

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: scheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0xFF000000).withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? primaryBlue : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? primaryBlue : textMuted,
            size: 24,
          );
        }),
        elevation: 0,
        height: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    );

    final clrPrimary = const Color(0xFFF9FAFB);
    final clrSec = const Color(0xFFD1D5DB);
    final clrMut = const Color(0xFF9CA3AF);

    final scheme = baseScheme.copyWith(
      primary: const Color(0xFF60A5FA),
      secondary: accentOrange,
      tertiary: accentPurple,
      surface: darkSurface,
      onSurface: clrPrimary,
      onPrimary: Colors.white,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(displayColor: clrPrimary, bodyColor: clrPrimary)
        .copyWith(
          titleLarge: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: clrPrimary, letterSpacing: -0.5),
          titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: clrPrimary, letterSpacing: -0.2),
          titleSmall: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: clrPrimary),
          bodyLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: clrPrimary),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w400, color: clrSec),
          bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: clrMut),
          labelLarge: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: clrPrimary),
          labelMedium: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w500, color: clrSec),
          labelSmall: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w500, color: clrMut),
        );

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: scheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: clrPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: clrPrimary, letterSpacing: -0.5),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0xFF000000).withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? const Color(0xFF60A5FA) : clrMut,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? const Color(0xFF60A5FA) : clrMut,
            size: 24,
          );
        }),
        elevation: 0,
        height: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF374151),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
        ),
      ),
    );
  }

  // ── Helper getters consumed by widgets ──────
  static List<Color> heroGradientFor(BuildContext context) {
    return heroGradient;
  }

  static Color coinGold(BuildContext context) => LmsAdminTheme.coinGold;
}
