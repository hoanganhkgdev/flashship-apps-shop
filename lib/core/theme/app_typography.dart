import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font size scale — thay cho số fontSize rải rác khắp app (trước đây có
/// hơn 20 giá trị lẻ như 13.5/11.5/9.5 do chỉnh tay qua thời gian).
class AppFontSize {
  // Giữ các alias cũ để không làm thay đổi API của Shop, nhưng giá
  // trị bám theo thang chữ của Driver.
  static const tiny = 10.0;
  static const xxs = 10.0;
  static const xs = 10.0;
  static const sm = 12.0;
  static const base = 14.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 28.0;
  static const display1 = 28.0;
  static const display2 = 32.0;
  static const display3 = 36.0;
  static const display4 = 40.0;
  static const hero = 48.0;
}

/// Shared typography for the shop app, used by both light and dark themes.
/// Change sizes in [AppFontSize] and the font family here.
/// System text scaling remains controlled by Flutter and the user's settings.
abstract final class AppTypography {
  static final fontFamily = GoogleFonts.inter().fontFamily;

  static TextStyle style({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextTheme textTheme(TextTheme base, {required Color color}) {
    return GoogleFonts.interTextTheme(
      base.copyWith(
        displayLarge: const TextStyle(
            fontSize: AppFontSize.hero, fontWeight: FontWeight.w700),
        displayMedium: const TextStyle(
            fontSize: AppFontSize.display3, fontWeight: FontWeight.w700),
        displaySmall: const TextStyle(
            fontSize: AppFontSize.display2, fontWeight: FontWeight.w700),
        headlineLarge: const TextStyle(
            fontSize: AppFontSize.display3, fontWeight: FontWeight.w700),
        headlineMedium: const TextStyle(
            fontSize: AppFontSize.display2, fontWeight: FontWeight.w700),
        headlineSmall: const TextStyle(
            fontSize: AppFontSize.display1, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(
            fontSize: AppFontSize.xxxl, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(
            fontSize: AppFontSize.xl, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(
            fontSize: AppFontSize.md, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: AppFontSize.lg),
        bodyMedium: const TextStyle(fontSize: AppFontSize.md),
        bodySmall: const TextStyle(fontSize: AppFontSize.sm),
        labelSmall: const TextStyle(
            fontSize: AppFontSize.sm, fontWeight: FontWeight.w600),
        labelMedium: const TextStyle(
            fontSize: AppFontSize.base, fontWeight: FontWeight.w600),
        labelLarge: const TextStyle(
            fontSize: AppFontSize.md, fontWeight: FontWeight.w600),
      ),
    ).apply(
      bodyColor: color,
      displayColor: color,
    );
  }
}
