import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tạo đơn mới',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpace.md),
          _PrimaryOrderAction(onTap: onDeliveryTap),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            Expanded(
              child: _SecondaryOrderAction(
                icon: Icons.move_to_inbox_outlined,
                title: 'Lấy hộ',
                subtitle: 'Lấy về shop',
                color: colors.info,
                backgroundColor: colors.infoSoft,
                onTap: onPickupTap,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _SecondaryOrderAction(
                icon: Icons.layers_outlined,
                title: 'Đơn gộp',
                subtitle: 'Nhiều điểm giao',
                color: colors.warning,
                backgroundColor: colors.warningSoft,
                onTap: onBatchTap,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PrimaryOrderAction extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryOrderAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.lg),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpace.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Giao đơn',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Giao hàng từ shop đến khách',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

class _SecondaryOrderAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _SecondaryOrderAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
