import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hằng số thương hiệu — giống nhau ở cả light/dark.
/// Màu phụ thuộc chế độ sáng/tối nằm trong [Palette] (lấy qua `context.colors`).
class AppColors {
  static const primary       = Color(0xFFE8720C);
  static const primaryDark   = Color(0xFFCC5A08);
  static const background    = Color(0xFFF5F6F8);
  static const surface       = Colors.white;
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const divider       = Color(0xFFE5E7EB);
  static const success       = Color(0xFF10B981);
  static const danger        = Color(0xFFEF4444);
  static const warning       = Color(0xFFF59E0B);
  static const info          = Color(0xFF3B82F6);
}

/// Spacing scale — dùng thay số lẻ rải rác.
class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radius scale.
class AppRadius {
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const card = 16.0;
  // Bo tròn hoàn toàn (field/button dạng viên thuốc) — số đủ lớn để luôn
  // vượt quá nửa chiều cao thực tế, Flutter tự giới hạn về hình viên thuốc.
  static const pill = 999.0;
}

/// Bảng màu theo chế độ sáng/tối. Lấy trong widget bằng `context.colors`.
class Palette extends ThemeExtension<Palette> {
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;   // nền nhạt của primary (chip, icon box…)
  final Color background;
  final Color surface;       // card, sheet, appbar
  final Color surfaceAlt;    // nền input, hàng xen kẽ
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;
  final Color shadow;

  const Palette({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.shadow,
  });

  static const light = Palette(
    primary:       AppColors.primary,
    onPrimary:     Colors.white,
    primarySoft:   Color(0xFFFDF0E3),
    background:    Color(0xFFF5F6F8),
    surface:       Colors.white,
    surfaceAlt:    Color(0xFFF3F4F6),
    textPrimary:   Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textTertiary:  Color(0xFF9CA3AF),
    divider:       Color(0xFFE5E7EB),
    success:       Color(0xFF10B981),
    successSoft:   Color(0xFFE7F8F1),
    danger:        Color(0xFFEF4444),
    dangerSoft:    Color(0xFFFEF2F2),
    warning:       Color(0xFFF59E0B),
    warningSoft:   Color(0xFFFEF7E8),
    info:          Color(0xFF3B82F6),
    infoSoft:      Color(0xFFEFF5FF),
    shadow:        Color(0x14111827),
  );

  static const dark = Palette(
    primary:       Color(0xFFF18A35), // sáng hơn một chút cho đủ tương phản nền tối
    onPrimary:     Colors.white,
    primarySoft:   Color(0xFF33231A),
    background:    Color(0xFF101216),
    surface:       Color(0xFF1A1D23),
    surfaceAlt:    Color(0xFF23262E),
    textPrimary:   Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary:  Color(0xFF6B7280),
    divider:       Color(0xFF2B2F38),
    success:       Color(0xFF34D399),
    successSoft:   Color(0xFF15281F),
    danger:        Color(0xFFF87171),
    dangerSoft:    Color(0xFF2E1A1A),
    warning:       Color(0xFFFBBF24),
    warningSoft:   Color(0xFF2C2415),
    info:          Color(0xFF60A5FA),
    infoSoft:      Color(0xFF18222F),
    shadow:        Color(0x66000000),
  );

  /// Bóng đổ mềm cho card.
  List<BoxShadow> get cardShadow => [
        BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 3)),
      ];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      primary:       l(primary, other.primary),
      onPrimary:     l(onPrimary, other.onPrimary),
      primarySoft:   l(primarySoft, other.primarySoft),
      background:    l(background, other.background),
      surface:       l(surface, other.surface),
      surfaceAlt:    l(surfaceAlt, other.surfaceAlt),
      textPrimary:   l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary:  l(textTertiary, other.textTertiary),
      divider:       l(divider, other.divider),
      success:       l(success, other.success),
      successSoft:   l(successSoft, other.successSoft),
      danger:        l(danger, other.danger),
      dangerSoft:    l(dangerSoft, other.dangerSoft),
      warning:       l(warning, other.warning),
      warningSoft:   l(warningSoft, other.warningSoft),
      info:          l(info, other.info),
      infoSoft:      l(infoSoft, other.infoSoft),
      shadow:        l(shadow, other.shadow),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get colors =>
      Theme.of(this).extension<Palette>() ?? Palette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static ThemeData get light => _build(Palette.light, Brightness.light);
  static ThemeData get dark  => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      surface: p.surface,
      error: p.danger,
    );

    final textTheme = GoogleFonts.beVietnamProTextTheme(
      ThemeData(colorScheme: colorScheme).textTheme,
    ).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      dividerColor: p.divider,
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadow,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: GoogleFonts.beVietnamPro(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            brightness == Brightness.light ? const Color(0xFF1F2937) : p.surfaceAlt,
        contentTextStyle: GoogleFonts.beVietnamPro(
          fontSize: 14, color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: TextStyle(color: p.textTertiary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.primary.withValues(alpha: 0.4),
          disabledForegroundColor: p.onPrimary.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          minimumSize: const Size(double.infinity, 50),
          textStyle: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: GoogleFonts.beVietnamPro(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }
}
