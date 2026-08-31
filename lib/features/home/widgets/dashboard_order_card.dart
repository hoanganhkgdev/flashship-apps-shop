part of '../screens/home_screen.dart';

// ─── Order Card (Grab style = customer pattern) ───────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  int get _progressStep => switch (order.status) {
        'assigned' => 0,
        'processing' => 1,
        'completed' => 2,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final receiver = order.receiverName?.trim();
    final destination = receiver == null || receiver.isEmpty
        ? order.deliveryAddress
        : '${order.deliveryAddress} · $receiver';

    // Thẻ trắng shadow riêng cho từng đơn — icon loại hàng + chấm trạng
    // thái, đồng bộ ActiveOrderCard của app driver.
    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.divider),
        ),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(code,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary)),
            ),
            Text(Fmt.currency(order.shippingFee),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.primary)),
          ]),
          const SizedBox(height: 5),
          Text(destination,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
          const SizedBox(height: 13),
          if (order.status == 'pending')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.warningSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: c.warning, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Đang tìm tài xế',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.warning)),
              ]),
            )
          else
            _OrderProgress(currentStep: _progressStep),
        ]),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  final int currentStep;
  const _OrderProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const labels = ['Đã nhận', 'Đã lấy', 'Hoàn thành'];
    return Column(children: [
      Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          _ProgressDot(active: i <= currentStep, current: i == currentStep),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep ? c.primary : c.divider,
              ),
            ),
        ],
      ]),
      const SizedBox(height: 7),
      Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Text(labels[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : i == labels.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        i == currentStep ? FontWeight.w700 : FontWeight.w500,
                    color: i == currentStep ? c.primary : c.textTertiary)),
          ),
      ]),
    ]);
  }
}

class _ProgressDot extends StatelessWidget {
  final bool active;
  final bool current;
  const _ProgressDot({required this.active, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: current ? 15 : 10,
      height: current ? 15 : 10,
      padding: current ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: current ? c.primarySoft : (active ? c.primary : c.surface),
        shape: BoxShape.circle,
        border: Border.all(color: active ? c.primary : c.divider, width: 2),
      ),
      child: current
          ? DecoratedBox(
              decoration:
                  BoxDecoration(color: c.primary, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
