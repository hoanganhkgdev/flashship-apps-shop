import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hằng số thương hiệu — giống nhau ở cả light/dark.
/// Màu phụ thuộc chế độ sáng/tối nằm trong [Palette] (lấy qua `context.colors`).
/// Bảng màu "tươi trẻ, thân thiện" (retail/e-commerce) — cam san hô làm chủ
/// đạo, xanh ngọc làm điểm nhấn phụ. Thay cho tông "công cụ vận hành" cũ.
class AppColors {
  static const primary = Color(0xFFF56333);
  static const primaryDark = Color(0xFFC74007);
  static const accent2 = Color(0xFF00B3B5);
  static const background = Color(0xFFFBF5F1);
  static const surface = Color(0xFFFFFDFB);
  static const textPrimary = Color(0xFF1C1410);
  static const textSecondary = Color(0xFF5F5651);
  static const divider = Color(0xFFE5DCD7);
  static const success = Color(0xFF218A45);
  static const danger = Color(0xFFCC3336);
  static const warning = Color(0xFFAC6900);
  static const info = Color(0xFF1F6DD8);
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

/// Radius scale — bo mềm hơn theo hướng thiết kế retail/e-commerce mới.
class AppRadius {
  static const sm = 10.0; // chip/badge
  static const md = 16.0; // field/card nhỏ
  static const lg = 20.0; // dialog
  static const xl = 24.0; // bottom sheet, hero card
  static const card = 20.0; // card
  static const full = 999.0; // nút bấm dạng pill
}

/// Bảng màu theo chế độ sáng/tối. Lấy trong widget bằng `context.colors`.
class Palette extends ThemeExtension<Palette> {
  final Color primary;
  final Color onPrimary;
  final Color primarySoft; // nền nhạt của primary (chip, icon box…)
  final Color accent2; // điểm nhấn phụ (xanh ngọc) — icon/shortcut/voucher
  final Color accent2Soft;
  final Color background;
  final Color surface; // card, sheet, appbar
  final Color surfaceAlt; // nền input, hàng xen kẽ
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
    required this.accent2,
    required this.accent2Soft,
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
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primarySoft: Color(0xFFFFE5D9),
    accent2: AppColors.accent2,
    accent2Soft: Color(0xFFD1F3F2),
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: Color(0xFFF5EDE8),
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: Color(0xFF938A86),
    divider: AppColors.divider,
    success: AppColors.success,
    successSoft: Color(0xFFD9F3DD),
    danger: AppColors.danger,
    dangerSoft: Color(0xFFFFE5E1),
    warning: AppColors.warning,
    warningSoft: Color(0xFFFFECC9),
    info: AppColors.info,
    infoSoft: Color(0xFFDDECFF),
    shadow: Color(0x1A1C1410),
  );

  static const dark = Palette(
    primary: Color(0xFFFF8355), // sáng hơn một chút cho đủ tương phản nền tối
    onPrimary: Colors.white,
    primarySoft: Color(0xFF3A2417),
    accent2: Color(0xFF3DDBDC),
    accent2Soft: Color(0xFF163330),
    background: Color(0xFF141110),
    surface: Color(0xFF1E1A18),
    surfaceAlt: Color(0xFF272220),
    textPrimary: Color(0xFFF5EFEB),
    textSecondary: Color(0xFFB0A6A0),
    textTertiary: Color(0xFF7A716C),
    divider: Color(0xFF332C28),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF17281C),
    danger: Color(0xFFFF6B6B),
    dangerSoft: Color(0xFF301818),
    warning: Color(0xFFE8A93E),
    warningSoft: Color(0xFF2E2312),
    info: Color(0xFF5B9BFF),
    infoSoft: Color(0xFF19212F),
    shadow: Color(0x66000000),
  );

  /// Shadow mềm dùng chung cho mọi card — đồng bộ app driver
  /// (color 0x14111827, blur 12, offset (0,3) ở light mode).
  List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: shadow.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6)),
      ];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      accent2: l(accent2, other.accent2),
      accent2Soft: l(accent2Soft, other.accent2Soft),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      divider: l(divider, other.divider),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get colors => Theme.of(this).extension<Palette>() ?? Palette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static ThemeData get light => _build(Palette.light, Brightness.light);
  static ThemeData get dark => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      surface: p.surface,
      error: p.danger,
    );

    final textTheme = GoogleFonts.robotoCondensedTextTheme(
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
        titleTextStyle: GoogleFonts.robotoCondensed(
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF1F2937)
            : p.surfaceAlt,
        contentTextStyle: GoogleFonts.robotoCondensed(
          fontSize: 14,
          color: Colors.white,
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
              borderRadius: BorderRadius.circular(AppRadius.full)),
          minimumSize: const Size(double.infinity, 50),
          textStyle: GoogleFonts.robotoCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full)),
          textStyle: GoogleFonts.robotoCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: GoogleFonts.robotoCondensed(
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
