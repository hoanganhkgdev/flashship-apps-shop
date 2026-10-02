part of '../../screens/order_detail_screen.dart';

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  const _RouteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      glow: c.accent2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.route_rounded, label: 'Lộ trình', iconColor: c.accent2),
        const SizedBox(height: AppSpacing.lg),
        _RouteStop(
          isFirst: true,
          color: c.danger,
          label: 'LẤY HÀNG',
          title: order.pickupPlaceName?.isNotEmpty == true
              ? order.pickupPlaceName
              : order.senderName?.isNotEmpty == true
                  ? order.senderName
                  : null,
          address: order.pickupAddress,
          phone: order.pickupPhone,
        ),
        _RouteStop(
          isFirst: false,
          color: c.success,
          label: 'GIAO HÀNG',
          title: order.deliveryPlaceName?.isNotEmpty == true
              ? order.deliveryPlaceName
              : order.receiverName?.isNotEmpty == true
                  ? order.receiverName
                  : null,
          address: order.deliveryAddress,
          phone: order.deliveryPhone,
        ),
      ]),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final bool isFirst;
  final Color color;
  final String label;
  final String? title;
  final String address;
  final String? phone;

  const _RouteStop({
    required this.isFirst,
    required this.color,
    required this.label,
    required this.address,
    this.title,
    this.phone,
  });

  static const _dot = 14.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = Container(width: 2, color: c.divider);
    final dot = Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color, width: 3),
      ),
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: _dot,
          child: Column(children: [
            if (isFirst) ...[
              const SizedBox(height: 2),
              dot,
              Expanded(child: bar),
            ] else ...[
              SizedBox(height: 2, child: bar),
              dot,
              const Spacer(),
            ],
          ]),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isFirst ? AppSpacing.lg : 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: AppTextStyles.caption
                      .copyWith(color: c.textTertiary, letterSpacing: .6)),
              const SizedBox(height: 3),
              if (title != null && title!.isNotEmpty) ...[
                Text(title!,
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 1),
              ],
              Text(address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(color: c.textSecondary)),
              if (phone?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () => callPhone(phone!),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.phone_rounded, size: 13, color: c.primary),
                    const SizedBox(width: 4),
                    Text(phone!,
                        style: AppTextStyles.label.copyWith(color: c.primary)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
