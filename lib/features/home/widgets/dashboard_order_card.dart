part of '../screens/home_screen.dart';

// ─── Order Card (Grab style = customer pattern) ───────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  // Hệ thống chỉ có 6 status thật (pending/assigned/processing/on_the_way/
  // completed/cancelled) — không có status riêng cho "giao thất bại" hay "huỷ
  // chờ xác nhận". Tín hiệu "cần chú ý" khả dụng duy nhất từ dữ liệu hiện có:
  // đơn còn 'pending' (chưa tìm được tài xế) quá lâu so với lúc tạo.
  static const _pendingAttentionThreshold = Duration(minutes: 15);

  bool get _needsAttention =>
      order.status == 'pending' &&
      DateTime.now().difference(order.createdAt) >= _pendingAttentionThreshold;

  Color _statusColor(Palette c) {
    if (_needsAttention) return c.danger;
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    return c.primary;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = _statusColor(c);
    final attention = _needsAttention;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';

    // Thẻ trắng shadow riêng cho từng đơn — icon loại hàng + chấm trạng
    // thái, đồng bộ ActiveOrderCard của app driver.
    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: c.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(code,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                attention ? 'Cần kiểm tra' : Fmt.orderStatus(order.status),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          Text('Giao tới ${order.deliveryAddress}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1, color: c.divider),
          ),
          Row(children: [
            Expanded(
              child: Text('COD ${Fmt.currency(order.codAmount ?? 0)}',
                  style: TextStyle(fontSize: 12, color: c.textTertiary)),
            ),
            Text(Fmt.currency(order.shippingFee),
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.primary)),
          ]),
        ]),
      ),
    );
  }
}
