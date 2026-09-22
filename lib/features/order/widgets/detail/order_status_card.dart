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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currentIdx = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isCancelled) ...[
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
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDone ? c.primary : c.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? c.primarySoft : c.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(stepIcon,
                          size: 14,
                          color: isDone ? Colors.white : c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          fontWeight:
                              isDone ? FontWeight.w700 : FontWeight.w400,
                          color: isCurrent
                              ? c.primary
                              : isDone
                                  ? c.textPrimary
                                  : c.textSecondary,
                        )),
                  ]),
                );
              } else {
                final leftStepIdx = (i - 1) ~/ 2 + 1;
                final lineDone = currentIdx >= leftStepIdx && currentIdx != -1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                        height: 1.5, color: lineDone ? c.primary : c.divider),
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
                      style: TextStyle(
                          fontSize: AppFontSize.sm, color: c.danger))),
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
