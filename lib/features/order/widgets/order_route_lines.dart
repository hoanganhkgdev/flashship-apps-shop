import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Hành trình lấy → giao: vòng rỗng (điểm lấy) nối chấm đặc (điểm giao) bằng
/// một đường mảnh. Dùng chung cho thẻ đơn ở trang chủ và danh sách đơn.
class OrderRouteLines extends StatelessWidget {
  final String pickup;
  final String delivery;
  final bool dimmed;

  const OrderRouteLines({
    super.key,
    required this.pickup,
    required this.delivery,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pickupColor = dimmed ? c.textTertiary : c.primary;
    final deliveryColor = dimmed ? c.textTertiary : c.success;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 14,
          child: Column(children: [
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: pickupColor),
            ),
            Expanded(
              child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: c.divider,
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: deliveryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup.isEmpty ? '—' : pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.sm, color: c.textTertiary)),
              const SizedBox(height: 8),
              Text(delivery.isEmpty ? '—' : delivery,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: dimmed ? c.textTertiary : c.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }
}
