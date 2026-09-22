part of '../../screens/order_detail_screen.dart';

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  const _RouteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: c.primary, shape: BoxShape.circle)),
              Expanded(
                  child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: c.accent2,
                      borderRadius: BorderRadius.circular(3))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteStop(
                    label: 'LẤY HÀNG',
                    title: order.pickupPlaceName?.isNotEmpty == true
                        ? order.pickupPlaceName
                        : order.senderName?.isNotEmpty == true
                            ? order.senderName
                            : null,
                    address: order.pickupAddress,
                    phone: order.pickupPhone,
                  ),
                  const SizedBox(height: 16),
                  _RouteStop(
                    label: 'GIAO HÀNG',
                    title: order.deliveryPlaceName?.isNotEmpty == true
                        ? order.deliveryPlaceName
                        : order.receiverName?.isNotEmpty == true
                            ? order.receiverName
                            : null,
                    address: order.deliveryAddress,
                    phone: order.deliveryPhone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final String? title;
  final String address;
  final String? phone;

  const _RouteStop({
    required this.label,
    required this.address,
    this.title,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: c.textSecondary)),
      const SizedBox(height: 3),
      if (title != null && title!.isNotEmpty) ...[
        Text(title!,
            style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        const SizedBox(height: 1),
      ],
      Text(address,
          style: TextStyle(fontSize: AppFontSize.base, color: c.textSecondary)),
    ]);
  }
}
