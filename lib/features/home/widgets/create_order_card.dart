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
    return Row(children: [
      Expanded(
        child: _ShortcutCard(
          icon: Icons.delivery_dining_outlined,
          title: 'Giao hàng',
          color: colors.primary,
          onTap: onDeliveryTap,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ShortcutCard(
          icon: Icons.location_on_outlined,
          title: 'Lấy hàng',
          color: colors.primary,
          onTap: onPickupTap,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ShortcutCard(
          icon: Icons.route_outlined,
          title: 'Đơn gộp',
          color: colors.primary,
          onTap: onBatchTap,
        ),
      ),
    ]);
  }
}

// ignore: unused_element
class _QuickCreateBar extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onBatchTap;
  const _QuickCreateBar({required this.onTap, required this.onBatchTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1410),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            GestureDetector(
              key: const ValueKey('batch-order-action'),
              onTap: onBatchTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tạo đơn ngay',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 1),
                  Text('Chỉ mất 30 giây',
                      style: TextStyle(
                          color: Colors.white70, fontSize: AppFontSize.sm)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.divider),
          ),
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
