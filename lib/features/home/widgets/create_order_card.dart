import '../../../core/widgets/app_decor_widgets.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Ba dịch vụ chính của Home (Giao hàng, Lấy hàng, Đơn gộp) ngang hàng nhau
/// trên ba ô bằng nhau, không có nền hay tiêu đề bao quanh.
class CreateOrderCard extends StatelessWidget {
  final VoidCallback onDeliveryTap;
  final VoidCallback onPickupTap;
  final VoidCallback onBatchTap;

  const CreateOrderCard({
    super.key,
    required this.onDeliveryTap,
    required this.onPickupTap,
    required this.onBatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // IntrinsicHeight: Row(stretch) cần chiều cao xác định, nếu không sẽ lỗi
    // "infinite height" khi nằm trong danh sách cuộn.
    final row = IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _ServiceTile(
            key: const ValueKey('delivery-order-action'),
            icon: Icons.delivery_dining_rounded,
            asset: 'assets/images/icon-delivery.png',
            title: 'Giao hàng',
            subtitle: 'Tới khách',
            color: c.primary,
            onTap: onDeliveryTap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ServiceTile(
            key: const ValueKey('pickup-order-action'),
            icon: Icons.move_to_inbox_rounded,
            asset: 'assets/images/icon-pickup.png',
            title: 'Lấy hàng',
            subtitle: 'Về cửa hàng',
            color: c.accent2,
            onTap: onPickupTap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ServiceTile(
            key: const ValueKey('batch-order-action'),
            icon: Icons.route_rounded,
            asset: 'assets/images/icon-batch.png',
            title: 'Đơn gộp',
            subtitle: 'Nhiều điểm',
            color: c.info,
            onTap: onBatchTap,
          ),
        ),
      ]),
    );

    // Nền kính lấy từ nền chung của app (AppBackdrop), không cần khung nền riêng.
    return row;
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;

  /// Ảnh minh hoạ thay cho icon (nếu có).
  final String? asset;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceTile({
    super.key,
    required this.icon,
    this.asset,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .35 : .10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // Kính: sáng ở góc trên-trái, trong hơn ở góc dưới-phải.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: .20),
                            Colors.white.withValues(alpha: .06),
                          ]
                        : [
                            Colors.white.withValues(alpha: .75),
                            Colors.white.withValues(alpha: .30),
                          ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: dark ? .25 : .85),
                      width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Vùng biểu tượng cao cố định để tên các dịch vụ luôn thẳng hàng.
                    SizedBox(
                      height: 64,
                      child: asset != null
                          ? Image.asset(asset!, height: 64, fit: BoxFit.contain)
                          : Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: glassIconDecoration(context, color,
                                  circle: true),
                              child: Icon(icon, color: color, size: 28),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                            color: c.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.textSecondary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
