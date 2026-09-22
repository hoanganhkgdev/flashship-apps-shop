import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font size scale — thay cho số fontSize rải rác khắp app (trước đây có
/// hơn 20 giá trị lẻ như 13.5/11.5/9.5 do chỉnh tay qua thời gian).
class AppFontSize {
  static const tiny = 10.0; // ký hiệu ngắn trong badge
  static const xxs = 11.0; // nhãn điều hướng, badge ngắn
  static const xs = 12.0; // caption, timestamp, chip
  static const sm = 12.0; // bodySmall, helper text
  static const base = 13.0; // text phụ mặc định
  static const md = 14.0; // bodyMedium, text mặc định
  static const lg = 15.0; // bodyLarge, nút bấm
  static const xl = 16.0; // titleMedium, appbar title
  static const xxl = 18.0; // section title
  static const xxxl = 20.0; // titleLarge
  static const display1 = 22.0; // headlineSmall
  static const display2 = 24.0; // headlineMedium
  static const display3 = 26.0; // headlineLarge
  static const display4 = 26.0; // số PIN, số lớn
  static const hero = 32.0; // splash/hero
}

/// Shared typography for the shop app, used by both light and dark themes.
/// Change sizes in [AppFontSize] and the font family here.
/// System text scaling remains controlled by Flutter and the user's settings.
abstract final class AppTypography {
  static TextStyle style({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextTheme textTheme(TextTheme base, {required Color color}) {
    return GoogleFonts.manropeTextTheme(
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
