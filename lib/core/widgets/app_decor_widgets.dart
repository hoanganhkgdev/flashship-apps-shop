import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Vòng tròn trang trí mờ, dùng làm hoạ tiết nền cho các header gradient.
class Bubble extends StatelessWidget {
  final double size, opacity;
  const Bubble(this.size, this.opacity, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

/// Khung header gradient cam dùng chung cho các tab (trang chủ, đơn hàng,
/// thống kê) — đồng bộ GradientHeaderShell của app tài xế: nền gradient + 3
/// bong bóng trang trí + một dải cuối cùng cùng màu nền để nối liền xuống nội
/// dung bên dưới.
class GradientHeaderShell extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const GradientHeaderShell({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientMiddle,
              AppColors.primaryGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          const Positioned(top: -40, right: -40, child: Bubble(150, 0.07)),
          const Positioned(top: 80, left: -30, child: Bubble(80, 0.05)),
          const Positioned(bottom: 40, right: 30, child: Bubble(55, 0.04)),
          Column(crossAxisAlignment: crossAxisAlignment, children: [
            ...children,
            Container(height: 20, color: context.colors.background),
          ]),
        ]),
      );
}

/// Ô vuông bo góc chứa icon, nền nhạt cùng màu — dùng cho lối tắt, chỉ số,
/// danh mục (giống AppIconBadge của app tài xế).
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: glassIconDecoration(context, color),
        // Icon tỉ lệ theo badge (44 → 24) để badge nhỏ không bị icon lấn.
        child: Icon(icon, color: color, size: (size * 0.55).roundToDouble()),
      );
}

/// Nền "kính màu" cho icon: gradient nhuốm [color] (đậm ở góc trên-trái, trong
/// ở góc dưới-phải), viền trắng sáng và bóng nhẹ cùng màu. [circle] cho icon
/// tròn; mặc định bo theo [AppRadius.md].
BoxDecoration glassIconDecoration(
  BuildContext context,
  Color color, {
  bool circle = false,
  double radius = AppRadius.md,
}) {
  final dark = context.isDark;
  return BoxDecoration(
    shape: circle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: circle ? null : BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: dark ? .38 : .30),
        color.withValues(alpha: dark ? .14 : .10),
      ],
    ),
    border: Border.all(
        color: Colors.white.withValues(alpha: dark ? .28 : .85), width: 1.1),
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: color.withValues(alpha: .16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
  );
}

/// Nút icon kính: dùng thay cho IconButton.filledTonal ở header và các hành
/// động nhanh.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final double size;
  final double iconSize;

  /// Nền trắng đặc có viền mảnh, icon màu chữ (dùng cho nút quay lại).
  final bool white;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.tooltip,
    this.size = 44,
    this.iconSize = AppSize.iconLg,
    this.white = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Material(
      color: Colors.transparent,
      child: Ink(
        width: size,
        height: size,
        decoration: white
            ? BoxDecoration(
                color: context.isDark ? c.surface : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.divider),
                boxShadow: context.isDark ? null : AppShadows.soft,
              )
            : glassIconDecoration(context, color),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Center(
              child: Icon(icon,
                  color: white ? c.textPrimary : color, size: iconSize)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Khung bottom sheet dùng chung: tay nắm, header (icon badge + tiêu đề + mô tả
/// + nút đóng), phần thân cuộn được và footer cố định. Tự tránh bàn phím và
/// vùng an toàn nên caller chỉ cần `isScrollControlled: true` khi có ô nhập.
class AppSheet extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  /// false khi [child] tự quản lý cuộn (ListView shrinkWrap…).
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  const AppSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.color,
    this.subtitle,
    this.footer,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.primary;
    return AnimatedPadding(
      duration: AppDuration.fast,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // Kính mờ: làm mờ phần trang phía sau sheet, phủ lớp surface gần đặc để chữ
      // luôn dễ đọc.
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              // Kính: sáng ở trên, hơi trong hơn ở dưới; vẫn đủ đặc để chữ dễ đọc.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: context.isDark
                    ? [
                        c.surface.withValues(alpha: .90),
                        c.surface.withValues(alpha: .80),
                      ]
                    : [
                        Colors.white.withValues(alpha: .92),
                        Colors.white.withValues(alpha: .80),
                      ],
              ),
              border: Border(
                  top: BorderSide(
                      color: Colors.white
                          .withValues(alpha: context.isDark ? .28 : .95),
                      width: 1.4)),
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textTertiary.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.md, AppSpacing.md),
                  child: Row(children: [
                    AppIconBadge(icon: icon, color: tint, size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTextStyles.screenTitle.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w800)),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(subtitle!,
                                style: AppTextStyles.label
                                    .copyWith(color: c.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.close_rounded,
                      iconSize: AppSize.iconMd,
                      size: 38,
                      color: c.textSecondary,
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ]),
                ),
                Divider(height: 1, color: c.divider),
                Flexible(
                  child: scrollable
                      ? SingleChildScrollView(padding: padding, child: child)
                      : child,
                ),
                if (footer != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.divider))),
                    child: footer,
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dòng lựa chọn trong sheet (chọn chế độ, khu vực…): icon, nhãn, dấu tick khi
/// đang chọn.
class AppSheetOption extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppSheetOption({
    super.key,
    this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.primarySoft : c.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon,
                  size: AppSize.iconMd,
                  color: selected ? c.primary : c.textSecondary),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyStrong
                      .copyWith(color: selected ? c.primary : c.textPrimary)),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: AppSize.iconMd, color: c.primary),
          ]),
        ),
      ),
    );
  }
}

/// Header chuẩn của mọi màn con: nút quay lại tonal cam, tiêu đề + mô tả, hành
/// động ở phải. Dùng được cả ở `Scaffold.appBar` lẫn đầu một `Column`; tự chừa
/// vùng status bar.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? trailing;
  final VoidCallback? onTitleLongPress;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.trailing,
    this.onTitleLongPress,
  });

  static const double _height = 76;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassHeader(
      padding: EdgeInsets.zero,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(children: [
              GlassIconButton(
                icon: backIcon,
                iconSize: 18,
                white: true,
                color: c.primary,
                tooltip: 'Quay lại',
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GestureDetector(
                  onLongPress: onTitleLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.screenTitle.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w800)),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label
                                .copyWith(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề mục đánh số của các màn nhập liệu (01, 02…).
class AppSectionHeading extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  const AppSectionHeading(
      {super.key,
      required this.number,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Text(number,
              style: AppTextStyles.label
                  .copyWith(color: c.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary)),
        ])),
      ]),
    );
  }
}

/// Nền toàn app cho phong cách liquid glass: gradient rất nhạt + vài đốm màu
/// loang mờ. Các card kính phía trên nhìn xuyên qua và ăn màu của lớp này.
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    Widget blob(Color color, double size, double alpha, Alignment at) => Align(
          alignment: at,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        );
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF17100C), Color(0xFF0C1517)]
                  : const [Color(0xFFFFF0E6), Color(0xFFE4F5F4)],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: Stack(children: [
          blob(c.primary, 380, dark ? .30 : .40, const Alignment(-1.2, -0.85)),
          blob(c.accent2, 420, dark ? .26 : .36, const Alignment(1.3, -0.1)),
          blob(c.info, 360, dark ? .22 : .28, const Alignment(-1.0, 0.95)),
          blob(c.primary, 300, dark ? .20 : .26, const Alignment(1.2, 1.0)),
        ]),
      ),
      child,
    ]);
  }
}

/// Card kính: nền trong + viền sáng + bóng nhẹ. [blur] > 0 khi nội dung cuộn
/// trượt phía dưới (header, menu, sheet) để làm mờ phần phía sau.
BoxDecoration glassDecoration(
  BuildContext context, {
  double radius = AppRadius.card,
  bool strong = false,
  bool shadow = true,
}) {
  final c = context.colors;
  return BoxDecoration(
    color: strong ? c.glassStrong : c.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: c.glassBorder, width: 1.2),
    boxShadow: shadow && !context.isDark ? AppShadows.soft : null,
  );
}

/// Header kính: nền kính mờ bo cong hai góc dưới, viền sáng và bóng nhẹ. Dùng
/// chung cho header của mọi trang.
class GlassHeader extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  const GlassHeader({super.key, required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const radius = BorderRadius.vertical(bottom: Radius.circular(28));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .30 : .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: .16),
                        Colors.white.withValues(alpha: .07),
                      ]
                    : [
                        Colors.white.withValues(alpha: .88),
                        Colors.white.withValues(alpha: .60),
                      ],
              ),
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: dark ? .22 : .9),
                    width: 1.2),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Card kính dùng cho danh sách: nền trắng trong chuyển sắc, viền sáng, bóng
/// nhẹ và vầng sáng mờ theo [glow] ở góc phải. [blur] = false cho danh sách dài
/// (BackdropFilter trên từng thẻ cuộn khá tốn) — nền trong vẫn ăn màu nền app.
class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? glow;
  final VoidCallback? onTap;
  final bool blur;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.glow,
    this.onTap,
    this.blur = true,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final radius = BorderRadius.circular(AppRadius.card);

    Widget body = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: .14),
                      Colors.white.withValues(alpha: .05),
                    ]
                  : [
                      Colors.white.withValues(alpha: .85),
                      Colors.white.withValues(alpha: .45),
                    ],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: dark ? .22 : .9),
                width: 1.2),
          ),
          child: Stack(children: [
            if (glow != null)
              Positioned(
                top: -50,
                right: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        glow!.withValues(alpha: dark ? .22 : .18),
                        glow!.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
    if (blur) {
      body = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: body);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark ? null : AppShadows.soft,
      ),
      child: ClipRRect(borderRadius: radius, child: body),
    );
  }
}
