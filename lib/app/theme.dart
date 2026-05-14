import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// BensinKu — Editorial Mono theme.
///
/// Vibe: car service manual / fuel pump LCD / paper logbook.
/// NOT: magazine blog post.
///
/// Typography:
///   - IBM Plex Mono — numbers, labels, eyebrows, headlines, masthead
///   - IBM Plex Sans — body text, descriptions, UI prose
///
/// Color:
///   - Cream paper canvas, butter spot accent, ink near-black text.
class AppEditorial {
  // ── Palette ──────────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFF6EFDF);
  static const Color canvasSoft = Color(0xFFFBF5E7);

  static const Color butter = Color(0xFFE9B341);
  static const Color butterDeep = Color(0xFFB6841C);
  static const Color butterSoft = Color(0xFFF6DC9F);

  static const Color cream = Color(0xFFFFF7E6);

  static const Color ink = Color(0xFF1A0F03);
  static const Color inkSoft = Color(0xFF6B5A45);
  static const Color inkMuted = Color(0xFF8E7B62);

  static const Color hairline = Color(0xFFD9CCAC);
  static const Color hairlineSoft = Color(0xFFEBE2C8);

  static const Color sage = Color(0xFF5C7042);
  static const Color rust = Color(0xFFA8391A);

  // ── Radii — kept tight, like terminal boxes ─────────────────────────
  static const double rCard = 6;
  static const double rButton = 4;
  static const double rPill = 999;
  static const double rTiny = 2;

  // ── Tabular figures ──────────────────────────────────────────────────
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  // ── Style helpers ────────────────────────────────────────────────────
  /// Mono — for numbers, codes, eyebrows, headlines.
  static TextStyle mono({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    bool tabular = true,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  /// Sans — for body prose, descriptions.
  static TextStyle sans({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) {
    return GoogleFonts.ibmPlexSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  /// `[LABEL]` eyebrow style — uppercase mono, wide-tracked.
  static TextStyle eyebrow({
    double fontSize = 10.5,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? inkSoft,
      letterSpacing: 0.4,
      height: 1.2,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppEditorial.ink,
      onPrimary: AppEditorial.canvas,
      primaryContainer: AppEditorial.butterSoft,
      onPrimaryContainer: AppEditorial.ink,
      secondary: AppEditorial.butterDeep,
      onSecondary: AppEditorial.canvas,
      secondaryContainer: AppEditorial.cream,
      onSecondaryContainer: AppEditorial.ink,
      tertiary: AppEditorial.sage,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFD8DEC2),
      onTertiaryContainer: Color(0xFF263014),
      error: AppEditorial.rust,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF5D5C5),
      onErrorContainer: Color(0xFF4F1A07),
      surface: AppEditorial.canvas,
      onSurface: AppEditorial.ink,
      surfaceContainerHighest: AppEditorial.cream,
      onSurfaceVariant: AppEditorial.inkSoft,
      outline: AppEditorial.inkMuted,
      outlineVariant: AppEditorial.hairline,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: AppEditorial.ink,
      onInverseSurface: AppEditorial.canvas,
      inversePrimary: AppEditorial.butter,
      surfaceTint: AppEditorial.butter,
    );

    final inputBorder = UnderlineInputBorder(
      borderSide: BorderSide(color: AppEditorial.hairline, width: 1),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppEditorial.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppEditorial.canvas,
        foregroundColor: AppEditorial.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppEditorial.canvas,
        toolbarHeight: 56,
        iconTheme: IconThemeData(color: AppEditorial.ink),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: AppEditorial.cream,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rCard)),
          side: BorderSide(color: AppEditorial.hairlineSoft, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppEditorial.hairline,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: false,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide:
              const BorderSide(color: AppEditorial.ink, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide:
              const BorderSide(color: AppEditorial.rust, width: 1.2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide:
              const BorderSide(color: AppEditorial.rust, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        labelStyle: GoogleFonts.ibmPlexMono(
          color: AppEditorial.inkSoft,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
        floatingLabelStyle: GoogleFonts.ibmPlexMono(
          color: AppEditorial.ink,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
        hintStyle: GoogleFonts.ibmPlexSans(
          color: AppEditorial.inkMuted,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppEditorial.ink,
          foregroundColor: AppEditorial.canvas,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppEditorial.rButton)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppEditorial.ink,
          side: const BorderSide(color: AppEditorial.ink, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppEditorial.rButton)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppEditorial.ink,
          textStyle: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppEditorial.hairline, width: 1),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rTiny)),
        ),
        backgroundColor: AppEditorial.cream,
        selectedColor: AppEditorial.butter,
        labelStyle: GoogleFonts.ibmPlexMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppEditorial.ink,
          letterSpacing: 0.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppEditorial.ink,
        contentTextStyle: GoogleFonts.ibmPlexMono(
          color: AppEditorial.canvas,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rTiny)),
        ),
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minLeadingWidth: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            const WidgetStatePropertyAll(AppEditorial.canvas),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppEditorial.ink;
          return AppEditorial.hairline;
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppEditorial.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rCard)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppEditorial.canvas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppEditorial.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppEditorial.ink,
      ),
    );

    // All headlines = mono, NOT italic, NOT serif.
    // Body = sans for readability.
    final textTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme)
        .apply(
          bodyColor: AppEditorial.ink,
          displayColor: AppEditorial.ink,
        )
        .copyWith(
          // Display — giant pump-LCD style numbers
          displayLarge: AppEditorial.mono(
            fontSize: 56,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.5,
            height: 1.0,
          ),
          displayMedium: AppEditorial.mono(
            fontSize: 44,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.0,
            height: 1.0,
          ),
          displaySmall: AppEditorial.mono(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
            height: 1.05,
          ),

          // Headlines — chunky mono titles
          headlineLarge: AppEditorial.mono(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            height: 1.15,
          ),
          headlineMedium: AppEditorial.mono(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            height: 1.2,
          ),
          headlineSmall: AppEditorial.mono(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.25,
          ),
          titleLarge: AppEditorial.mono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          titleMedium: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          titleSmall: AppEditorial.mono(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),

          // Body — sans for prose
          bodyLarge: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppEditorial.ink,
          ),
          bodyMedium: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: AppEditorial.ink,
          ),
          bodySmall: GoogleFonts.ibmPlexSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: AppEditorial.inkSoft,
          ),

          // Labels — mono uppercase eyebrow style
          labelLarge: AppEditorial.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          labelMedium: AppEditorial.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppEditorial.inkSoft,
            letterSpacing: 0.4,
          ),
          labelSmall: AppEditorial.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppEditorial.inkSoft,
            letterSpacing: 0.6,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: AppEditorial.mono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITORIAL PRIMITIVES — kept minimal, all mono
// ─────────────────────────────────────────────────────────────────────────────

/// `[LABEL]` mono uppercase. The most-used section marker.
class EditorialEyebrow extends StatelessWidget {
  const EditorialEyebrow(this.label,
      {super.key, this.color, this.fontSize = 10.5, this.bracket = true});

  final String label;
  final Color? color;
  final double fontSize;
  final bool bracket;

  @override
  Widget build(BuildContext context) {
    final text = bracket
        ? '[ ${label.toUpperCase()} ]'
        : label.toUpperCase();
    return Text(
      text,
      style: AppEditorial.eyebrow(fontSize: fontSize, color: color),
    );
  }
}

/// Hairline horizontal rule.
class EditorialDivider extends StatelessWidget {
  const EditorialDivider({super.key, this.thickness = 1, this.color});
  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      color: color ?? AppEditorial.hairline,
    );
  }
}

/// Soft cream card with hairline border.
class EditorialCard extends StatelessWidget {
  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderColor,
    this.radius = AppEditorial.rCard,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? background;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppEditorial.cream,
        border: Border.all(
          color: borderColor ?? AppEditorial.hairlineSoft,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: box,
    );
  }
}

/// Section header: `TITLE  ················` style.
/// Bold mono label + dotted leader to the right.
/// `index` parameter is kept for backward compat but no longer rendered.
class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    this.index,
    required this.label,
    this.trailing,
  });

  /// Deprecated, retained only so existing call sites compile.
  final String? index;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomPaint(
            painter: _DottedLinePainter(color: AppEditorial.hairline),
            child: const SizedBox(height: 1),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Key-value row with dotted leader, like a service log.
/// `Total ........... Rp 50.000`
class EditorialDataRow extends StatelessWidget {
  const EditorialDataRow({
    super.key,
    required this.label,
    required this.value,
    this.isLast = false,
    this.valueStyle,
    this.dense = false,
    this.dotted = true,
  });

  final String label;
  final String value;
  final bool isLast;
  final TextStyle? valueStyle;
  final bool dense;
  final bool dotted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast
                ? Colors.transparent
                : (dotted ? Colors.transparent : AppEditorial.hairline),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
            ),
          ),
          if (dotted) ...[
            const SizedBox(width: 8),
            Expanded(
              child: CustomPaint(
                painter: _DottedLinePainter(
                  color: AppEditorial.hairline,
                  dotSpacing: 4,
                  dotSize: 1,
                ),
                child: const SizedBox(height: 1),
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const Spacer(),
          Text(
            value,
            style: valueStyle ??
                AppEditorial.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppEditorial.ink,
                  tabular: true,
                ),
          ),
        ],
      ),
    );
  }
}

/// Big readout — for hero numbers like a pump display.
/// Renders as: `Rp50.000` with prefix small + value huge mono.
class EditorialReadout extends StatelessWidget {
  const EditorialReadout({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.fontSize = 44,
    this.color,
  });

  final String value;
  final String? prefix;
  final String? suffix;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          if (prefix != null)
            TextSpan(
              text: prefix,
              style: AppEditorial.mono(
                fontSize: fontSize * 0.42,
                fontWeight: FontWeight.w500,
                color: color ?? AppEditorial.inkSoft,
              ),
            ),
          TextSpan(
            text: value,
            style: AppEditorial.mono(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              letterSpacing: -fontSize * 0.022,
              color: color,
            ),
          ),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: AppEditorial.mono(
                fontSize: fontSize * 0.36,
                fontWeight: FontWeight.w500,
                color: color ?? AppEditorial.inkSoft,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({
    required this.color,
    this.dotSpacing = 3,
    this.dotSize = 1,
  });

  final Color color;
  final double dotSpacing;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dotSize
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height / 2), dotSize / 2, paint);
      x += dotSpacing;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) =>
      old.color != color ||
      old.dotSpacing != dotSpacing ||
      old.dotSize != dotSize;
}
