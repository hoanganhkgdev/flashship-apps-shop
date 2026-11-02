part of '../screens/home_screen.dart';

/// Card đơn đang thực hiện: loại dịch vụ, trạng thái, tuyến đường, tài xế và phí.
class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({super.key, required this.order});

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
    final name = order.receiverName?.trim() ?? '';
    final phone = order.deliveryPhone.trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    return order.isBatch ? '${order.stops.length} điểm giao' : 'Người nhận';
  }

  String get _deliveryAddress {
    if (!order.isBatch || order.stops.isEmpty) return order.deliveryAddress;
    final first = '${order.stops.first['address'] ?? order.deliveryAddress}';
    final remaining = order.stops.length - 1;
    return remaining > 0 ? '$first · và $remaining điểm khác' : first;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = switch (order.status) {
      'pending' => (label: 'Đang tìm tài xế', color: c.primary),
      'assigned' => (label: 'Tài xế đang đến lấy', color: c.info),
      'processing' => (label: 'Đang trên đường giao', color: c.success),
      _ => (label: Fmt.orderStatus(order.status), color: c.textSecondary),
    };
    final serviceColor = order.isBatch
        ? c.info
        : order.shopServiceType == 'shop_pickup'
            ? c.accent2
            : c.primary;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';

    void open() => context.push('/order/${order.code}');

    return Semantics(
      button: true,
      label: '$_serviceTitle $code, ${status.label}',
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset(
                        _serviceAsset,
                        fit: BoxFit.contain,
                        cacheWidth: 132,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _serviceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            code,
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width < 360 ? 108 : 136,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: status.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _OrderRouteRow(
                        icon: Icons.radio_button_checked_rounded,
                        color: serviceColor,
                        label: 'Điểm lấy',
                        title: order.storeName?.trim().isNotEmpty == true
                            ? order.storeName!.trim()
                            : 'Cửa hàng',
                        address: order.pickupAddress,
                      ),
                      const SizedBox(height: 10),
                      _OrderRouteRow(
                        icon: Icons.location_on_rounded,
                        color: c.danger,
                        label: order.isBatch ? 'Các điểm giao' : 'Điểm giao',
                        title: _recipient,
                        address: _deliveryAddress,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: c.divider),
                const SizedBox(height: 8),
                _OrderCardFooter(
                  order: order,
                  color: serviceColor,
                  onOpen: open,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String address;

  const _OrderRouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCardFooter extends StatelessWidget {
  final OrderModel order;
  final Color color;
  final VoidCallback onOpen;

  const _OrderCardFooter({
    required this.order,
    required this.color,
    required this.onOpen,
  });

  String get _driverLabel {
    final name = order.driver?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    return switch (order.status) {
      'pending' => 'Đang kết nối tài xế',
      'assigned' => 'Tài xế đã nhận đơn',
      _ => Fmt.orderStatus(order.status),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final driver = Row(children: [
      Icon(Icons.person_rounded, size: 17, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          _driverLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ]);
    final fee = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Phí ship',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: c.textTertiary,
          ),
        ),
        Text(
          Fmt.currency(order.shippingFee),
          maxLines: 1,
          style: AppTextStyles.label.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 380 ||
          MediaQuery.textScalerOf(context).scale(12) > 15;
      final button = TextButton.icon(
        onPressed: onOpen,
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: .10),
          minimumSize: Size(compact ? double.infinity : 0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text('Xem chi tiết'),
      );

      if (compact) {
        return Column(children: [
          Row(children: [
            Expanded(child: driver),
            const SizedBox(width: 8),
            fee,
          ]),
          const SizedBox(height: 9),
          button,
        ]);
      }
      return Row(children: [
        Expanded(child: driver),
        const SizedBox(width: 10),
        fee,
        const SizedBox(width: 10),
        button,
      ]);
    });
  }
}
