import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// BensinKu — Design System.
///
/// Arah: aplikasi finansial/utilitas modern bergaya digital-bank (MyPertamina,
/// Livin', Jago, blu). Light mode, identitas kuat lewat panel brand kuning,
/// kartu putih bersih, dan tipografi berkarakter. Flat, tanpa gradient.
///
/// Typography:
///   - Sora — angka, total, judul, wordmark (geometris, percaya diri)
///   - Inter — body, label, caption, prosa UI
class AppEditorial {
  // ── Brand ────────────────────────────────────────────────────────────
  /// Kuning brand utama — dipakai sebagai blok warna besar (hero panel).
  static const Color brand = Color(0xFFF5BE2E);
  static const Color brandBright = Color(0xFFFFD34E);
  static const Color brandDeep = Color(0xFF8A5E10);
  static const Color brandSoft = Color(0xFFFCEFC9);
  static const Color brandTint = Color(0xFFFBF4DE);

  // Alias lama (tetap dipakai banyak call-site).
  static const Color butter = brand;
  static const Color butterDeep = brandDeep;
  static const Color butterSoft = brandSoft;

  // ── Neutral ──────────────────────────────────────────────────────────
  /// Latar aplikasi — abu sangat terang netral hangat (khas app perbankan).
  static const Color canvas = Color(0xFFF3F2EF);
  static const Color canvasSoft = Color(0xFFF8F7F4);

  /// Permukaan kartu — putih bersih.
  static const Color cream = Color(0xFFFFFFFF);

  /// Teks.
  static const Color ink = Color(0xFF1B1A17);
  static const Color inkSoft = Color(0xFF5E5A52);
  static const Color inkMuted = Color(0xFF9A958A);

  /// Garis & pemisah.
  static const Color hairline = Color(0xFFEAE7E0);
  static const Color hairlineSoft = Color(0xFFF1EFE9);

  /// Status.
  static const Color sage = Color(0xFF3F7D51);
  static const Color sageSoft = Color(0xFFE3EFE5);
  static const Color rust = Color(0xFFC8482E);
  static const Color rustSoft = Color(0xFFF7E2DB);

  // ── Radii ──────────────────────────────────────────────────────────
  static const double rCard = 24;
  static const double rButton = 16;
  static const double rPill = 999;
  static const double rTiny = 14;

  // ── Bayangan halus (no gradient) ─────────────────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF1B1A17).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get brandShadow => [
        BoxShadow(
          color: brand.withValues(alpha: 0.32),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  // ── Tabular figures ──────────────────────────────────────────────────
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  // ── Style helpers ────────────────────────────────────────────────────
  /// Numerik — angka, total, nominal (Sora, tegas & rapi).
  static TextStyle mono({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
    bool tabular = true,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing ?? -0.3,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  /// Sans — body text, label, caption, prosa UI.
  static TextStyle sans({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  /// Heading — display, judul besar, wordmark (Sora).
  static TextStyle heading({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing ?? -0.4,
      height: height,
    );
  }

  /// Eyebrow — label kecil uppercase (Inter, korporat).
  static TextStyle eyebrow({
    double fontSize = 11,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? inkMuted,
      letterSpacing: 0.8,
      height: 1.2,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppEditorial.ink,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppEditorial.brandSoft,
      onPrimaryContainer: AppEditorial.ink,
      secondary: AppEditorial.brandDeep,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: AppEditorial.brandSoft,
      onSecondaryContainer: AppEditorial.ink,
      tertiary: AppEditorial.sage,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: AppEditorial.sageSoft,
      onTertiaryContainer: Color(0xFF1F3A28),
      error: AppEditorial.rust,
      onError: Color(0xFFFFFFFF),
      errorContainer: AppEditorial.rustSoft,
      onErrorContainer: Color(0xFF52200F),
      surface: AppEditorial.cream,
      onSurface: AppEditorial.ink,
      surfaceContainerHighest: AppEditorial.canvasSoft,
      onSurfaceVariant: AppEditorial.inkSoft,
      outline: AppEditorial.inkMuted,
      outlineVariant: AppEditorial.hairline,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: AppEditorial.ink,
      onInverseSurface: AppEditorial.canvas,
      inversePrimary: AppEditorial.brand,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1.4]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEditorial.rButton),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppEditorial.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppEditorial.canvas,
        foregroundColor: AppEditorial.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rCard)),
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
        filled: true,
        fillColor: AppEditorial.canvasSoft,
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(AppEditorial.ink, 1.6),
        errorBorder: inputBorder(AppEditorial.rust),
        focusedErrorBorder: inputBorder(AppEditorial.rust, 1.6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        labelStyle: GoogleFonts.inter(
          color: AppEditorial.inkSoft,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: AppEditorial.ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppEditorial.inkMuted,
          fontWeight: FontWeight.w400,
          fontSize: 14.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppEditorial.ink,
          foregroundColor: const Color(0xFFFFFFFF),
          disabledBackgroundColor: AppEditorial.hairline,
          disabledForegroundColor: AppEditorial.inkMuted,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppEditorial.rButton)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppEditorial.ink,
          side: const BorderSide(color: AppEditorial.hairline, width: 1.4),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppEditorial.rButton)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          textStyle: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppEditorial.brandDeep,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: const StadiumBorder(),
        backgroundColor: AppEditorial.canvasSoft,
        selectedColor: AppEditorial.brand,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppEditorial.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppEditorial.ink,
        contentTextStyle: GoogleFonts.inter(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rButton)),
        ),
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minLeadingWidth: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppEditorial.ink;
          return AppEditorial.hairline;
        }),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppEditorial.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppEditorial.rCard)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppEditorial.canvas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppEditorial.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppEditorial.ink,
      ),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(
          bodyColor: AppEditorial.ink,
          displayColor: AppEditorial.ink,
        )
        .copyWith(
          displayLarge: AppEditorial.heading(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.8,
            height: 1.0,
          ),
          displayMedium: AppEditorial.heading(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            height: 1.02,
          ),
          displaySmall: AppEditorial.heading(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            height: 1.08,
          ),
          headlineLarge: AppEditorial.heading(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.18,
          ),
          headlineMedium: AppEditorial.heading(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.22,
          ),
          headlineSmall: AppEditorial.heading(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.3,
          ),
          titleLarge: AppEditorial.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: AppEditorial.heading(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: AppEditorial.heading(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppEditorial.ink,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppEditorial.ink,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: AppEditorial.inkSoft,
          ),
          labelLarge: AppEditorial.heading(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppEditorial.inkSoft,
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppEditorial.inkSoft,
            letterSpacing: 0.3,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: AppEditorial.heading(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Label kecil uppercase. Bersih, tanpa kurung.
class EditorialEyebrow extends StatelessWidget {
  const EditorialEyebrow(this.label,
      {super.key, this.color, this.fontSize = 11, this.bracket = true});

  final String label;
  final Color? color;
  final double fontSize;
  final bool bracket;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppEditorial.eyebrow(fontSize: fontSize, color: color),
    );
  }
}

/// Garis pemisah tipis.
class EditorialDivider extends StatelessWidget {
  const EditorialDivider({super.key, this.thickness = 1, this.color});
  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      color: color ?? AppEditorial.hairlineSoft,
    );
  }
}

/// Kartu putih dengan sudut membulat & bayangan halus.
class EditorialCard extends StatelessWidget {
  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.background,
    this.borderColor,
    this.radius = AppEditorial.rCard,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? background;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppEditorial.cream,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? AppEditorial.softShadow : null,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

/// Header bagian: judul tebal + opsional trailing (mis. "Lihat semua").
/// `index` dipertahankan agar call-site lama tetap kompilasi.
class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    this.index,
    required this.label,
    this.trailing,
  });

  final String? index;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _titleCase(label),
            style: AppEditorial.heading(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }

  static String _titleCase(String input) {
    return input
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Tautan "Lihat semua" gaya banking — pill lembut.
class EditorialSeeAll extends StatelessWidget {
  const EditorialSeeAll({super.key, required this.onTap, this.label = 'Lihat semua'});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppEditorial.sans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppEditorial.brandDeep,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(PhosphorIconsRegular.caretRight,
              size: 18, color: AppEditorial.brandDeep),
        ],
      ),
    );
  }
}

/// Baris key-value bersih: label kiri, value kanan.
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
      padding: EdgeInsets.symmetric(vertical: dense ? 9 : 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppEditorial.hairlineSoft,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppEditorial.sans(
                fontSize: 13.5,
                color: AppEditorial.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: valueStyle ??
                AppEditorial.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.ink,
                  tabular: true,
                ),
          ),
        ],
      ),
    );
  }
}

/// Angka besar — untuk nominal hero.
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
              style: AppEditorial.heading(
                fontSize: fontSize * 0.44,
                fontWeight: FontWeight.w600,
                color: color ?? AppEditorial.inkSoft,
              ),
            ),
          TextSpan(
            text: value,
            style: AppEditorial.heading(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -fontSize * 0.03,
              color: color,
            ),
          ),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: AppEditorial.heading(
                fontSize: fontSize * 0.36,
                fontWeight: FontWeight.w600,
                color: color ?? AppEditorial.inkSoft,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedCount — angka yang "menghitung naik" (count-up) saat muncul/berubah.
// ─────────────────────────────────────────────────────────────────────────────

/// Menampilkan angka dengan animasi count-up. Saat pertama tampil ia menghitung
/// dari 0; saat nilainya berubah ia menghitung mulus dari nilai sebelumnya.
///
/// `formatter` mengubah nilai numerik menjadi string siap-tampil
/// (mis. `(v) => 'Rp ${rupiah.format(v).trim()}'`).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final double value;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // TweenAnimationBuilder otomatis menganimasikan dari nilai berjalan ke
      // `end` baru tiap rebuild — `begin` hanya dipakai pada frame pertama.
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        formatter(v),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton — placeholder loading dengan animasi "pulse" halus (tanpa gradient).
// ─────────────────────────────────────────────────────────────────────────────

/// Kotak placeholder yang berdenyut lembut saat data masih dimuat.
/// Warnanya beranimasi antara dua tone netral (atau bisa di-override untuk
/// area di atas panel kuning lewat [baseColor]).
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppEditorial.rTiny,
    this.baseColor,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? baseColor;
  final BoxShape shape;

  /// Bulat penuh (lingkaran), mis. untuk avatar.
  const Skeleton.circle({super.key, required double size, Color? color})
      : width = size,
        height = size,
        radius = 0,
        baseColor = color,
        shape = BoxShape.circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppEditorial.hairline;
    final hi = Color.lerp(base, AppEditorial.canvasSoft, 0.6)!;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(base, hi, _c.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
