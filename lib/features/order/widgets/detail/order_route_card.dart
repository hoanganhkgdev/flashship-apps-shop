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
                      color: c.success,
                      borderRadius: BorderRadius.circular(3))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteStop(
                    label: 'Lấy hàng',
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
                    label: 'Giao đến',
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary)),
      const SizedBox(height: 3),
      if (title != null && title!.isNotEmpty) ...[
        Text(title!,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        const SizedBox(height: 1),
      ],
      Text(address, style: TextStyle(fontSize: 14, color: c.textPrimary)),
      if (phone != null && phone!.isNotEmpty) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => callPhone(phone!),
          child: Row(children: [
            Icon(Icons.phone_outlined, size: 13, color: c.primary),
            const SizedBox(width: 4),
            Text(phone!,
                style: TextStyle(
                    fontSize: 13,
                    color: c.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ]);
  }
}
