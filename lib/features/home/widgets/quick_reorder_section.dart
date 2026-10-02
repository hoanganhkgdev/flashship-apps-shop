part of '../screens/home_screen.dart';

// ─── Đặt lại nhanh ───────────────────────────────────────────────────────────
//
// Các điểm giao shop hay gửi nhất, lấy từ đơn đã hoàn thành gần đây (trùng
// địa chỉ + SĐT chỉ hiện một lần) — chạm một lần là mở màn tạo đơn đã điền sẵn.

class _QuickReorderSection extends ConsumerWidget {
  const _QuickReorderSection();

  static const _maxItems = 6;

  String _key(OrderModel o) => o.isBatch
      ? 'batch|${o.stops.length}|${o.stops.isNotEmpty ? o.stops.first['address'] : ''}'
      : '${o.deliveryAddress.trim().toLowerCase()}|${o.deliveryPhone.trim()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderListProvider).orders;
    final seen = <String>{};
    final recent = <OrderModel>[];
    for (final o in orders) {
      if (!o.isCompleted || !seen.add(_key(o))) continue;
      recent.add(o);
      if (recent.length == _maxItems) break;
    }
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(icon: Icons.replay_rounded, title: 'Đặt lại nhanh'),
      SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Chừa chỗ cho bóng thẻ không bị cắt.
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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

  String get _title {
    if (order.isBatch) return '${order.stops.length} điểm giao';
    final name = order.receiverName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final place = order.deliveryPlaceName?.trim();
    if (place != null && place.isNotEmpty) return place;
    return order.deliveryPhone.isNotEmpty ? order.deliveryPhone : 'Người nhận';
  }

  String get _address => order.isBatch && order.stops.isNotEmpty
      ? '${order.stops.first['address'] ?? ''}'
      : order.deliveryAddress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => reorderOrder(context, order),
      child: Container(
        width: 232,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: c.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.glassBorder, width: 1.2),
          boxShadow: c.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(_address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppFontSize.base,
                  height: 1.3,
                  color: c.textSecondary)),
          const Spacer(),
          Row(children: [
            Text(Fmt.currency(order.shippingFee),
                style:
                    AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.replay_rounded, size: 14, color: c.primary),
                const SizedBox(width: 4),
                Text('Đặt lại',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.primary)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}
