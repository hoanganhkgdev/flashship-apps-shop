part of '../../screens/order_detail_screen.dart';

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  static const _steps = [
    ('assigned', 'Đã nhận', Icons.check_rounded),
    ('processing', 'Đã lấy', Icons.delivery_dining_rounded),
    ('completed', 'Hoàn thành', Icons.check_rounded),
  ];

  static const _statusOrder = [
    'pending',
    'assigned',
    'processing',
    'completed'
  ];

  static (IconData, String, String) _summary(String status) => switch (status) {
        'pending' => (
            Icons.search_rounded,
            'Đang tìm tài xế',
            'Đơn đã được gửi, vui lòng chờ trong giây lát'
          ),
        'assigned' => (
            Icons.two_wheeler_rounded,
            'Tài xế đang đến lấy hàng',
            'Tài xế đã nhận đơn của bạn'
          ),
        'processing' => (
            Icons.local_shipping_rounded,
            'Đang giao hàng',
            'Tài xế đã lấy hàng và đang trên đường giao'
          ),
        'completed' => (
            Icons.check_circle_rounded,
            'Giao hàng thành công',
            'Đơn hàng đã hoàn tất'
          ),
        _ => (
            Icons.cancel_rounded,
            'Đơn đã huỷ',
            'Đơn hàng không còn hiệu lực'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currentIdx = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';
    final tone = Fmt.statusColor(order.status);
    final (icon, title, subtitle) = _summary(order.status);

    return _FlatCard(
      glow: tone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIconBadge(icon: icon, color: tone, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.screenTitle.copyWith(
                        color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle,
                    style:
                        AppTextStyles.label.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ]),
        if (!isCancelled) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isEven) {
                final (key, label, stepIcon) = _steps[i ~/ 2];
                final stepIdx = _statusOrder.indexOf(key);
                final isDone = currentIdx >= stepIdx && currentIdx != -1;
                final isCurrent = order.status == key;
                return SizedBox(
                  width: 72,
                  child: Column(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? c.primary : c.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? c.primarySoft : c.divider,
                          width: isCurrent ? 3 : 1.5,
                        ),
                      ),
                      child: Icon(stepIcon,
                          size: 15,
                          color: isDone ? Colors.white : c.textTertiary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight:
                              isDone ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? c.primary
                              : isDone
                                  ? c.textPrimary
                                  : c.textTertiary,
                        )),
                  ]),
                );
              }
              final leftStepIdx = (i - 1) ~/ 2 + 1;
              final lineDone = currentIdx >= leftStepIdx && currentIdx != -1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                          color: lineDone ? c.primary : c.divider,
                          borderRadius: BorderRadius.circular(1))),
                ),
              );
            }),
          ),
        ],
        if (isCancelled && order.cancelReason != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: c.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(order.cancelReason!,
                      style: AppTextStyles.label.copyWith(color: c.danger))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Pending animated dots ────────────────────────────────────────────────────

// Giữ animation để có thể tái sử dụng ở trạng thái tìm tài xế toàn màn hình.
// ignore: unused_element
class _PendingDots extends StatefulWidget {
  final Color color;
  const _PendingDots({required this.color});

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final opacity =
              (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Opacity(
              opacity: opacity,
              child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle)),
            ),
          );
        }),
      ),
    );
  }
}
