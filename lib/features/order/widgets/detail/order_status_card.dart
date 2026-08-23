part of '../../screens/order_detail_screen.dart';

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  static String _subtitle(String status) {
    switch (status) {
      case 'pending':
        return 'Đang tìm tài xế phù hợp...';
      case 'assigned':
        return 'Tài xế đang trên đường đến';
      case 'processing':
        return 'Tài xế đang lấy hàng';
      case 'on_the_way':
        return 'Tài xế đang giao hàng';
      case 'completed':
        return 'Giao hàng thành công!';
      case 'cancelled':
        return 'Đơn hàng đã bị huỷ';
      default:
        return status;
    }
  }

  static const _steps = [
    ('pending', 'Tìm tài xế', Icons.schedule_rounded),
    ('assigned', 'Đã nhận', Icons.person_pin_rounded),
    ('processing', 'Lấy hàng', Icons.inventory_2_outlined),
    ('completed', 'Hoàn thành', Icons.check_circle_rounded),
  ];

  static const _statusOrder = [
    'pending',
    'assigned',
    'processing',
    'on_the_way',
    'completed'
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = Fmt.statusColor(order.status);
    final icon = Fmt.statusIcon(order.status);
    final subtitle = _subtitle(order.status);
    final currentIdx = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Current status
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.orderStatus(order.status),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: color.withValues(alpha: 0.85))),
              if (order.status == 'pending') ...[
                const SizedBox(height: 8),
                _PendingDots(color: color),
              ],
            ],
          )),
        ]),

        // Horizontal stepper
        if (!isCancelled) ...[
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isEven) {
                final (key, label, stepIcon) = _steps[i ~/ 2];
                final stepIdx = _statusOrder.indexOf(key);
                final isDone = currentIdx >= stepIdx && currentIdx != -1;
                return SizedBox(
                  width: 60,
                  child: Column(children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone ? color : c.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? color : c.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(stepIcon,
                          size: 13,
                          color: isDone ? Colors.white : c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isDone ? FontWeight.w700 : FontWeight.w400,
                          color: isDone ? c.textPrimary : c.textSecondary,
                        )),
                  ]),
                );
              } else {
                final leftStepIdx = (i - 1) ~/ 2 + 1;
                final lineDone = currentIdx >= leftStepIdx && currentIdx != -1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                        height: 2,
                        color: lineDone
                            ? color.withValues(alpha: 0.4)
                            : c.divider),
                  ),
                );
              }
            }),
          ),
        ],

        // Cancel reason
        if (isCancelled && order.cancelReason != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.dangerSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.danger.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: c.danger),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(order.cancelReason!,
                      style: TextStyle(fontSize: 12, color: c.danger))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Pending animated dots ────────────────────────────────────────────────────

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
