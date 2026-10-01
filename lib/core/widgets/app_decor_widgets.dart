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
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: color, size: 24),
      );
}
