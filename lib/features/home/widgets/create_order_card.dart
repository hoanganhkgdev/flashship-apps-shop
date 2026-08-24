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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Thanh CTA tối màu — bấm vào là vào thẳng luồng giao hàng
        // (đúng hành động phổ biến nhất) ─────────────────────────────
        _QuickCreateBar(onTap: onDeliveryTap, onBatchTap: onBatchTap),
        const SizedBox(height: 16),

        // ── 2 ô thao tác chính ────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _ShortcutCard(
              icon: Icons.local_shipping_outlined,
              title: 'Giao hàng',
              subtitle: 'Shop giao đơn cho khách',
              color: colors.primary,
              backgroundColor: colors.primarySoft,
              onTap: onDeliveryTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ShortcutCard(
              icon: Icons.location_on_outlined,
              title: 'Lấy hàng ngoài',
              subtitle: 'Tài xế lấy hộ hàng hoá',
              color: colors.accent2,
              backgroundColor: colors.accent2Soft,
              onTap: onPickupTap,
            ),
          ),
        ]),
      ],
    );
  }
}

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
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 1),
                  Text('Chỉ mất 30 giây',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5)),
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
  final String subtitle;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ShortcutCard({
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
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: colors.cardShadow,
          ),
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}
