import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'home_section_heading.dart';

/// Lưới dịch vụ vuông, cùng cấu trúc và nhịp thị giác với app customer.
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ShopHomeSectionHeading(
        title: 'Tạo đơn mới',
        highlight: 'đơn mới',
        subtitle: 'Chọn dịch vụ, tạo đơn ngay',
        subtitleIcon: Icons.bolt_rounded,
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth < 328 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 2
            : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          _ServiceTile(
            key: const ValueKey('delivery-order-action'),
            width: width,
            title: 'Giao hàng',
            subtitle: 'Giao tới khách',
            asset: 'assets/images/icon-delivery.png',
            color: context.colors.primary,
            onTap: onDeliveryTap,
          ),
          _ServiceTile(
            key: const ValueKey('pickup-order-action'),
            width: width,
            title: 'Lấy hàng',
            subtitle: 'Nhận về shop',
            asset: 'assets/images/icon-pickup.png',
            color: context.colors.accent2,
            onTap: onPickupTap,
          ),
          _ServiceTile(
            key: const ValueKey('batch-order-action'),
            width: width,
            title: 'Đơn gộp',
            subtitle: 'Giao nhiều điểm',
            asset: 'assets/images/icon-batch.png',
            color: context.colors.info,
            onTap: onBatchTap,
          ),
        ]);
      }),
    ]);
  }
}

class _ServiceTile extends StatefulWidget {
  final double width;
  final String title, subtitle, asset;
  final Color color;
  final VoidCallback onTap;

  const _ServiceTile({
    super.key,
    required this.width,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Tạo đơn ${widget.title}',
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox.square(
          dimension: widget.width,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) {
                if (_pressed != value) setState(() => _pressed = value);
              },
              child: Ink(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _pressed
                      ? widget.color.withValues(alpha: .07)
                      : c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _pressed
                        ? widget.color.withValues(alpha: .28)
                        : c.divider,
                  ),
                ),
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 72,
                        child: Image.asset(
                          widget.asset,
                          fit: BoxFit.contain,
                          cacheWidth: 216,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      height: 1.16,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      height: 1.15,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
