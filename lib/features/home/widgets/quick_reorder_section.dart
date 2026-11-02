part of '../screens/home_screen.dart';

// Các điểm giao shop hay gửi nhất, lọc từ đơn hoàn thành gần đây.
class _QuickReorderSection extends ConsumerWidget {
  const _QuickReorderSection();

  static const _maxItems = 6;

  String _key(OrderModel o) => o.isBatch
      ? 'batch|${o.stops.length}|${o.stops.isNotEmpty ? o.stops.first['address'] : ''}'
      : '${o.shopServiceType}|${o.deliveryAddress.trim().toLowerCase()}|${o.deliveryPhone.trim()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderListProvider).orders;
    final seen = <String>{};
    final recent = <OrderModel>[];
    for (final order in orders) {
      if (!order.isCompleted || !seen.add(_key(order))) continue;
      recent.add(order);
      if (recent.length == _maxItems) break;
    }
    if (recent.isEmpty) return const SizedBox.shrink();

    final scaleDelta =
        (MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(0, 3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ShopHomeSectionHeading(
        title: 'Gửi lại nhanh',
        highlight: 'lại nhanh',
        subtitle: 'Tạo lại đơn cho khách hàng gần đây',
        subtitleIcon: Icons.history_rounded,
      ),
      SizedBox(
        height: 228 + scaleDelta * 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _ReorderTile(order: recent[i]),
        ),
      ),
    ]);
  }
}

class _ReorderTile extends StatelessWidget {
  final OrderModel order;

  const _ReorderTile({required this.order});

  String get _serviceTitle {
    if (order.isBatch) return 'Đơn gộp';
    return order.shopServiceType == 'shop_pickup' ? 'Lấy hàng' : 'Giao hàng';
  }

  String get _serviceAsset {
    if (order.isBatch) return 'assets/images/icon-batch.png';
    return order.shopServiceType == 'shop_pickup'
        ? 'assets/images/icon-pickup.png'
        : 'assets/images/icon-delivery.png';
  }

  String get _recipient {
    if (order.isBatch) return '${order.stops.length} điểm giao';
    final name = order.receiverName?.trim() ?? '';
    final phone = order.deliveryPhone.trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
    if (name.isNotEmpty) return name;
    return phone.isNotEmpty ? phone : 'Người nhận';
  }

  String get _deliveryAddress => order.isBatch && order.stops.isNotEmpty
      ? '${order.stops.first['address'] ?? order.deliveryAddress}'
      : order.deliveryAddress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = order.isBatch
        ? c.info
        : order.shopServiceType == 'shop_pickup'
            ? c.accent2
            : c.primary;
    final width =
        (MediaQuery.sizeOf(context).width - 48).clamp(260.0, 300.0).toDouble();

    return Semantics(
      button: true,
      label: 'Gửi lại $_serviceTitle cho $_recipient',
      child: SizedBox(
        width: width,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => reorderOrder(context, order),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        _serviceAsset,
                        fit: BoxFit.contain,
                        cacheWidth: 114,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _serviceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Fmt.timeAgo(order.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.replay_rounded, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          'Gửi lại',
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(children: [
                      _ReorderRouteLine(
                        icon: Icons.radio_button_checked_rounded,
                        color: color,
                        title: order.storeName?.trim().isNotEmpty == true
                            ? order.storeName!.trim()
                            : 'Cửa hàng',
                        address: order.pickupAddress,
                      ),
                      const SizedBox(height: 8),
                      _ReorderRouteLine(
                        icon: Icons.location_on_rounded,
                        color: c.danger,
                        title: _recipient,
                        address: _deliveryAddress,
                      ),
                    ]),
                  ),
                  const Spacer(),
                  Divider(height: 1, color: c.divider),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(
                        'Phí lần trước',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.currency(order.shippingFee),
                      maxLines: 1,
                      style: AppTextStyles.label.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReorderRouteLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String address;

  const _ReorderRouteLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
