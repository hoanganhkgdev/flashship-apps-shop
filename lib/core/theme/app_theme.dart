import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_typography.dart';

export 'app_typography.dart';

/// Hằng số thương hiệu — giống nhau ở cả light/dark.
/// Màu phụ thuộc chế độ sáng/tối nằm trong [Palette] (lấy qua `context.colors`).
/// Bảng màu "tươi trẻ, thân thiện" (retail/e-commerce) — cam san hô làm chủ
/// đạo, xanh ngọc làm điểm nhấn phụ. Thay cho tông "công cụ vận hành" cũ.
class AppColors {
  // Bảng màu đồng bộ với app tài xế.
  static const primary = Color(0xFFFF6035);
  static const primaryDark = Color(0xFFD83A05);
  static const primaryGradientStart = Color(0xFFCC5A08);
  static const primaryGradientMiddle = Color(0xFFE8720C);
  static const primaryGradientEnd = Color(0xFFF59E30);
  static const accent2 = Color(0xFF008F92);
  static const background = Color(0xFFF2F3F5);
  static const surface = Color(0xFFFFFEFD);
  static const textPrimary = Color(0xFF1B1411);
  static const textSecondary = Color(0xFF6A605C);
  static const divider = Color(0xFFE5DDD9);
  static const success = Color(0xFF229650);
  static const danger = Color(0xFFD52E36);
  static const warning = Color(0xFFBE7900);
  static const info = Color(0xFF3B82F6);
}

/// Spacing scale — dùng thay số lẻ rải rác.
class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
  static const xl5 = 48.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Tên token giống Driver; [AppSpace] được giữ lại cho code Shop cũ.
abstract final class AppSpacing {
  static const xxs = AppSpace.xxs;
  static const xs = AppSpace.xs;
  static const sm = AppSpace.sm;
  static const md = AppSpace.md;
  static const lg = AppSpace.lg;
  static const xl = 20.0;
  static const xl2 = AppSpace.xl2;
  static const xl3 = AppSpace.xl3;
  static const xl4 = AppSpace.xl4;
  static const xl5 = AppSpace.xl5;
}

/// Radius scale — bo mềm hơn theo hướng thiết kế retail/e-commerce mới.
class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0; // chip/badge
  static const md = 10.0; // field/card nhỏ
  static const lg = 14.0; // dialog
  static const xl = 16.0; // bottom sheet, hero card
  static const card = 14.0; // card
  static const full = 999.0; // nút bấm dạng pill
}

abstract final class AppSize {
  static const minTouchTarget = 48.0;
  static const buttonHeight = 50.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppTextStyles {
  static const screenTitle = TextStyle(
      fontSize: AppFontSize.xl, height: 1.2, fontWeight: FontWeight.w600);
  static const sectionTitle = TextStyle(
      fontSize: AppFontSize.md, height: 1.25, fontWeight: FontWeight.w800);
  static const body = TextStyle(
      fontSize: AppFontSize.base, height: 1.4, fontWeight: FontWeight.w500);
  static const bodyStrong = TextStyle(
      fontSize: AppFontSize.base, height: 1.35, fontWeight: FontWeight.w700);
  static const label = TextStyle(
      fontSize: AppFontSize.sm, height: 1.3, fontWeight: FontWeight.w600);
  static const caption = TextStyle(
      fontSize: AppFontSize.xs, height: 1.3, fontWeight: FontWeight.w600);
  static const metric = TextStyle(
      fontSize: AppFontSize.xl,
      height: 1.1,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.2);
  static const metricLarge = TextStyle(
      fontSize: AppFontSize.display2,
      height: 1.05,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6);
}

abstract final class AppShadows {
  static const soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F1B1411),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A1B1411),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
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

  // Liquid glass: nền kính trong (card), kính đặc hơn (header/menu/sheet) và
  // viền sáng của kính.
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;

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
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
  });

  static const light = Palette(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primarySoft: Color(0xFFFFEAE3),
    accent2: AppColors.accent2,
    accent2Soft: Color(0xFFE3F5F4),
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: Color(0xFFF5F5F5),
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: Color(0xFF938A86),
    divider: AppColors.divider,
    success: AppColors.success,
    successSoft: Color(0xFFE7F8F1),
    danger: AppColors.danger,
    dangerSoft: Color(0xFFFFE5E2),
    warning: AppColors.warning,
    warningSoft: Color(0xFFFFF1CC),
    info: AppColors.info,
    infoSoft: Color(0xFFEFF5FF),
    shadow: Color(0x1A1B1411),
    glass: Color(0xA8FFFFFF),
    glassStrong: Color(0xD6FFFFFF),
    glassBorder: Color(0xE6FFFFFF),
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
    glass: Color(0x14FFFFFF),
    glassStrong: Color(0x26FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
  );

  /// Bóng mềm dùng chung cho mọi thẻ — đồng bộ AppShadows.soft của app tài xế
  /// (blur 16, lệch xuống 4).
  List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: shadow.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 4)),
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
      glass: l(glass, other.glass),
      glassStrong: l(glassStrong, other.glassStrong),
      glassBorder: l(glassBorder, other.glassBorder),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get colors => Theme.of(this).extension<Palette>() ?? Palette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Vệt sáng kính phủ lên nút đặc: sáng ở nửa trên, trong dần xuống dưới. Phủ
/// trong suốt nên màu gốc của nút (cam, đỏ, vàng, cam nhạt...) vẫn giữ nguyên.
Widget _glassGloss(BuildContext context, Set<WidgetState> states, Widget? child) {
  final k = states.contains(WidgetState.disabled) ? .5 : 1.0;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: .34 * k),
          Colors.white.withValues(alpha: .07 * k),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, .55, 1],
      ),
    ),
    child: child,
  );
}

Widget _glassFill(Set<WidgetState> states, Widget? child, List<Color> colors) {
  final k = states.contains(WidgetState.disabled) ? .6 : 1.0;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [for (final c in colors) c.withValues(alpha: c.a * k)],
      ),
    ),
    child: child,
  );
}

Widget _glassFillLight(BuildContext context, Set<WidgetState> states, Widget? child) =>
    _glassFill(states, child, [
      Colors.white.withValues(alpha: .78),
      Colors.white.withValues(alpha: .34),
    ]);

Widget _glassFillDark(BuildContext context, Set<WidgetState> states, Widget? child) =>
    _glassFill(states, child, [
      Colors.white.withValues(alpha: .12),
      Colors.white.withValues(alpha: .04),
    ]);

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

    final textTheme = AppTypography.textTheme(
      ThemeData(colorScheme: colorScheme).textTheme,
      color: p.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [p],
      // Nền thật do AppBackdrop vẽ (gradient + đốm màu) để kính có thứ làm mờ.
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: p.divider,
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        toolbarHeight: 60,
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 2,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadow,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: AppTypography.style(
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: p.shadow,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        margin: EdgeInsets.zero,
      ),
      // Nền sheet trong suốt: AppSheet tự vẽ lớp kính mờ, nếu để surface đặc ở
      // đây thì phần kính bị che mất.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        contentTextStyle: AppTypography.style(
          fontSize: AppFontSize.md,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: TextStyle(color: p.textTertiary, fontSize: AppFontSize.base),
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
          textStyle: AppTypography.style(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w700,
          ),
          // Kính: viền trắng mảnh đi theo hình dạng của từng nút + vệt sáng
          // phủ lên màu gốc (nên nút đỏ/vàng/cam nhạt vẫn giữ màu của nó).
          side: BorderSide(
              color: Colors.white
                  .withValues(alpha: brightness == Brightness.dark ? .22 : .55),
              width: 1),
        ).copyWith(
          backgroundBuilder: _glassGloss,
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary.withValues(alpha: .7), width: 1.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full)),
          textStyle: AppTypography.style(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          // Kính trong: nền trắng mờ chuyển sắc bên trong viền màu.
          backgroundBuilder: brightness == Brightness.dark
              ? _glassFillDark
              : _glassFillLight,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: AppTypography.style(
            fontSize: AppFontSize.base,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
              Size(AppSize.minTouchTarget, AppSize.minTouchTarget)),
          iconSize: const WidgetStatePropertyAll(AppSize.iconLg),
          foregroundColor: WidgetStatePropertyAll(p.textPrimary),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          )),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySoft,
        indicatorShape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.divider;
          return states.contains(WidgetState.selected)
              ? p.success
              : p.textTertiary;
        }),
        thumbColor: WidgetStatePropertyAll(p.onPrimary),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 4,
        shape: const StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.primarySoft,
        disabledColor: p.surfaceAlt,
        side: BorderSide(color: p.divider),
        shape: const StadiumBorder(),
        labelStyle: AppTextStyles.label.copyWith(color: p.textSecondary),
        secondaryLabelStyle: AppTextStyles.label.copyWith(color: p.primary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
    );
  }
}
