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
    final cargo = cargoTypeOf(order.cargoType);
    final statusColor = _statusColor(c);
    final attention = _needsAttention;

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
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Icon loại hàng ────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cargo.color
                      .withValues(alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cargo.icon, color: cargo.color, size: 20),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(cargo.label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                      ),
                      Text(Fmt.currency(order.shippingFee),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                    ]),
                    const SizedBox(height: 4),
                    if (attention) ...[
                      // ── Dòng cảnh báo thay cho chấm trạng thái mặc định ──
                      Row(children: [
                        Icon(Icons.error_rounded, size: 13, color: c.danger),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Chưa tìm được tài xế — cần kiểm tra lại',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.danger)),
                        ),
                      ]),
                    ] else ...[
                      Row(children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(Fmt.orderStatus(order.status),
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: c.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(order.deliveryAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary)),
                      ),
                      const SizedBox(width: 6),
                      Text(Fmt.timeAgo(order.createdAt),
                          style:
                              TextStyle(fontSize: 11, color: c.textTertiary)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
          // ── Chấm tròn báo hiệu ở góc trái ────────────────────────────
          if (attention)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c.danger, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }
}
