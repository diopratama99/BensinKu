import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    // Soft, muted palette — easy on the eyes
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF3D7A8A),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD6EEF3),
      onPrimaryContainer: Color(0xFF1A4A55),
      secondary: Color(0xFF4A9680),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFCEEDE4),
      onSecondaryContainer: Color(0xFF1A4035),
      tertiary: Color(0xFF7A8F4A),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE4EDCC),
      onTertiaryContainer: Color(0xFF3A4520),
      error: Color(0xFFBA4B4B),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFE8E8),
      onErrorContainer: Color(0xFF6B2020),
      surface: Color(0xFFF8FAFB),
      onSurface: Color(0xFF1E2C30),
      surfaceContainerHighest: Color(0xFFE8F2F5),
      onSurfaceVariant: Color(0xFF4D6870),
      outline: Color(0xFF7A9BA3),
      outlineVariant: Color(0xFFC8DADF),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF253035),
      onInverseSurface: Color(0xFFEBF3F5),
      inversePrimary: Color(0xFF9FD0DC),
      surfaceTint: Color(0xFF3D7A8A),
    );

    const radius = 16.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Very light, almost white-blue scaffold
      scaffoldBackgroundColor: const Color(0xFFF2F8FA),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 62,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: Colors.white.withValues(alpha: 0.95),
        shape: shape,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: shape.copyWith(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
          shape: shape.copyWith(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primaryContainer;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimaryContainer;
            }
            return colorScheme.onSurfaceVariant;
          }),
          textStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 13,
            );
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 6,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        )
        .copyWith(
          headlineLarge: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colorScheme.onSurface,
          ),
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
          headlineSmall: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colorScheme.onSurface,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: colorScheme.onSurface,
          ),
          titleMedium: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          titleSmall: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          bodyLarge: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
          bodySmall: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          labelLarge: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: colorScheme.onSurface,
          ),
          labelMedium: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: colorScheme.onSurface,
          ),
          labelSmall: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: colorScheme.onSurfaceVariant,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
