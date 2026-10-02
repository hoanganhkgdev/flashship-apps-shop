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
    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    const gap = SizedBox(height: AppSpacing.md);
    final expired = !order.canRate &&
        order.isCompleted &&
        order.driverRating == null &&
        order.completedAt != null &&
        DateTime.now().difference(order.completedAt!).inHours > 24;

    return RefreshIndicator(
      color: c.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xl4),
        children: [
          _StatusCard(order: order),
          gap,
          if (order.driver != null) ...[
            _DriverCard(
              order: order,
              realtimeLat: realtimeLat,
              realtimeLng: realtimeLng,
            ),
            gap,
          ],
          // Đơn gộp: danh sách điểm giao / đơn lẻ: thẻ lộ trình.
          if (order.isBatch && order.stops.isNotEmpty)
            _StopsCard(order: order, onStopDelivered: onRefresh)
          else
            _RouteCard(order: order),
          gap,
          _OrderInfoCard(order: order),
          if (order.orderNote?.isNotEmpty == true) ...[
            gap,
            _NoteCard(note: order.orderNote!),
          ],
          if (order.driverRating != null) ...[
            gap,
            _RatingDisplay(rating: order.driverRating!),
          ],
          if (expired) ...[
            gap,
            Padding(
              padding: pad,
              child: Text(
                  'Đã quá thời hạn đánh giá (24 giờ sau khi hoàn thành)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            ),
          ],
          if (order.canRate && !ratingDone) ...[
            gap,
            Padding(
              padding: pad,
              child: FilledButton.icon(
                onPressed: onRate,
                style: FilledButton.styleFrom(
                  backgroundColor: c.warning,
                  foregroundColor: Colors.white,
                  minimumSize:
                      const Size(double.infinity, AppSize.buttonHeight),
                ),
                icon: const Icon(Icons.star_rounded, size: AppSize.iconMd),
                label: const Text('Đánh giá tài xế'),
              ),
            ),
          ],
          if (order.isCompleted || order.isCancelled) ...[
            gap,
            Padding(
              padding: pad,
              child: OutlinedButton.icon(
                onPressed: () => reorderOrder(context, order),
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, AppSize.buttonHeight),
                ),
                icon: const Icon(Icons.replay_rounded, size: AppSize.iconMd),
                label: const Text('Đặt lại đơn tương tự'),
              ),
            ),
          ],
          if (order.canCancel) ...[
            gap,
            Padding(
              padding: pad,
              child: OutlinedButton.icon(
                onPressed: cancelling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.danger,
                  side: BorderSide(color: c.danger.withValues(alpha: .4)),
                  minimumSize:
                      const Size(double.infinity, AppSize.buttonHeight),
                ),
                icon: cancelling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.danger))
                    : const Icon(Icons.close_rounded, size: AppSize.iconMd),
                label: const Text('Huỷ đơn hàng'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
