import 'package:flutter/material.dart';

/// Font size scale — thay cho số fontSize rải rác khắp app (trước đây có
/// hơn 20 giá trị lẻ như 13.5/11.5/9.5 do chỉnh tay qua thời gian).
class AppFontSize {
  // Giữ alias cũ cho Shop; các vai trò chữ bên dưới khớp app customer.
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

  static const caption = 12.0;
  static const body = 14.0;
  static const bodyLarge = 16.0;
  static const title = 18.0;
  static const titleLarge = 20.0;
  static const heading = 24.0;
}

/// Shared typography for the shop app, used by both light and dark themes.
/// Change sizes in [AppFontSize] and the font family here.
/// System text scaling remains controlled by Flutter and the user's settings.
abstract final class AppTypography {
  static const fontFamily = 'Inter';

  static TextStyle style({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextTheme textTheme(TextTheme base, {required Color color}) {
    return base
        .copyWith(
          displayLarge: const TextStyle(
              fontSize: AppFontSize.hero, fontWeight: FontWeight.w700),
          displayMedium: const TextStyle(
              fontSize: AppFontSize.display3, fontWeight: FontWeight.w700),
          displaySmall: const TextStyle(
              fontSize: AppFontSize.display2, fontWeight: FontWeight.w700),
          headlineLarge: const TextStyle(fontSize: 32),
          headlineMedium: const TextStyle(fontSize: 28),
          headlineSmall: const TextStyle(fontSize: AppFontSize.heading),
          titleLarge: const TextStyle(fontSize: AppFontSize.titleLarge),
          titleMedium: const TextStyle(fontSize: AppFontSize.bodyLarge),
          titleSmall: const TextStyle(fontSize: AppFontSize.body),
          bodyLarge: const TextStyle(fontSize: AppFontSize.bodyLarge),
          bodyMedium: const TextStyle(fontSize: AppFontSize.body),
          bodySmall: const TextStyle(fontSize: AppFontSize.caption),
          labelSmall: const TextStyle(fontSize: AppFontSize.caption),
          labelMedium: const TextStyle(fontSize: AppFontSize.caption),
          labelLarge: const TextStyle(fontSize: AppFontSize.body),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: color,
          displayColor: color,
        );
  }
}
