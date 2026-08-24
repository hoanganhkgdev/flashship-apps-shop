part of '../../screens/order_detail_screen.dart';

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final OrderModel order;
  final double? realtimeLat, realtimeLng;
  final bool cancelling, ratingDone;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCancel;
  final VoidCallback onRate;

  const _Body({
    required this.order,
    this.realtimeLat,
    this.realtimeLng,
    required this.cancelling,
    required this.ratingDone,
    required this.onRefresh,
    required this.onCancel,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),

          // ── Status ───────────────────────────────────────────────────
          _StatusCard(order: order),
          const SizedBox(height: 12),

          // ── Driver ───────────────────────────────────────────────────
          if (order.driver != null) ...[
            _DriverCard(order: order),
            const SizedBox(height: 12),
          ],

          // Vị trí tài xế vẫn được cập nhật realtime; bản đồ được lược khỏi
          // trang tóm tắt để giữ bố cục gọn đúng thiết kế.

          // ── Route ─────────────────────────────────────────────────────
          // Batch: stops list / Single: route card
          if (order.isBatch && order.stops.isNotEmpty) ...[
            _StopsCard(order: order, onStopDelivered: onRefresh),
          ] else
            _RouteCard(order: order),
          const SizedBox(height: 12),

          // ── Order info ─────────────────────────────────────────────────
          _OrderInfoCard(order: order),

          // ── Note ───────────────────────────────────────────────────────
          if (order.orderNote?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _NoteCard(note: order.orderNote!),
          ],

          // ── Cancel button ──────────────────────────────────────────────
          if (order.canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: TextButton(
                onPressed: cancelling ? null : onCancel,
                style: TextButton.styleFrom(foregroundColor: c.danger),
                child: cancelling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.danger))
                    : const Text('Huỷ đơn hàng',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],

          // ── Rate button ────────────────────────────────────────────────
          if (order.canRate && !ratingDone) ...[
            const SizedBox(height: 12),
            _FlatCard(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.warning,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Đánh giá tài xế',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          // Nút đánh giá bị ẩn do quá 24h (canRate == false) nhưng chưa từng
          // đánh giá — báo lý do thay vì im lặng không hiện gì, tránh shop
          // tưởng app thiếu tính năng.
          if (!order.canRate &&
              order.isCompleted &&
              order.driverRating == null &&
              order.completedAt != null &&
              DateTime.now().difference(order.completedAt!).inHours > 24) ...[
            const SizedBox(height: 12),
            Text('Đã quá thời hạn đánh giá (24 giờ sau khi hoàn thành)',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],

          if (order.driverRating != null) ...[
            const SizedBox(height: 12),
            _RatingDisplay(rating: order.driverRating!),
          ],

          // ── Đặt lại ──────────────────────────────────────────────────
          if (order.isCompleted || order.isCancelled) ...[
            const SizedBox(height: 12),
            _FlatCard(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => order.isBatch
                      ? context.push('/create-batch',
                          extra: _reorderBatchExtra(order))
                      : context.push('/create-order',
                          extra: _reorderExtra(order)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Đặt lại đơn tương tự',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Tạo extra data để pre-fill CreateOrderScreen từ đơn cũ
  Map<String, dynamic> _reorderExtra(OrderModel o) {
    final isOutbound = o.shopServiceType != 'shop_pickup';
    return {
      'isOutbound': isOutbound,
      'pickupAddr': o.pickupAddress,
      'pickupLat': o.pickupLat,
      'pickupLng': o.pickupLng,
      'pickupPhone': o.pickupPhone,
      'pickupName': o.senderName,
      'deliveryAddr': o.deliveryAddress,
      'deliveryLat': o.deliveryLat,
      'deliveryLng': o.deliveryLng,
      'deliveryPhone': o.deliveryPhone,
      'deliveryName': o.receiverName,
      'cargoType': o.cargoType,
      'note': o.orderNote,
    };
  }

  /// Tạo extra data để pre-fill CreateBatchOrderScreen từ 1 đơn gộp cũ — SĐT
  /// lấy hàng không đưa vào đây, CreateBatchOrderScreen tự điền lại từ hồ sơ
  /// shop giống luồng tạo đơn mới (batch luôn lấy tại chính shop).
  Map<String, dynamic> _reorderBatchExtra(OrderModel o) {
    return {
      'pickupAddr': o.pickupAddress,
      'pickupLat': o.pickupLat,
      'pickupLng': o.pickupLng,
      'cargoType': o.cargoType,
      'stops': o.stops
          .map((s) => {
                'address': s['address'] as String? ?? '',
                'lat': (s['lat'] as num?)?.toDouble(),
                'lng': (s['lng'] as num?)?.toDouble(),
                'phone': s['phone'] as String? ?? '',
                'name': s['name'] as String? ?? '',
                'codAmount': (s['cod_amount'] as num?)?.toInt(),
                'note': s['note'] as String? ?? '',
              })
          .toList(),
    };
  }
}
