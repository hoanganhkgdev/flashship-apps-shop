part of '../../screens/order_detail_screen.dart';

// ─── Stops Card (batch orders) ───────────────────────────────────────────────

class _StopsCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final Future<void> Function() onStopDelivered;
  const _StopsCard({required this.order, required this.onStopDelivered});

  @override
  ConsumerState<_StopsCard> createState() => _StopsCardState();
}

class _StopsCardState extends ConsumerState<_StopsCard> {
  // Seq đang gọi API deliver — cho phép nhiều điểm loading độc lập, chỉ hiện
  // spinner trên đúng nút vừa bấm thay vì che cả màn hình.
  final Set<int> _deliveringSeqs = {};

  Future<void> _markDelivered(int seq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận giao hàng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('Xác nhận đã giao điểm $seq?',
            style: TextStyle(fontSize: 14, color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.primary),
            child: const Text('Xác nhận',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deliveringSeqs.add(seq));
    try {
      await ref
          .read(orderRepositoryProvider)
          .deliverStop(widget.order.code, seq);
      await widget.onStopDelivered();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
            context,
            parseApiError(e,
                fallback: 'Không thể đánh dấu đã giao. Thử lại sau.'));
      }
    } finally {
      if (mounted) setState(() => _deliveringSeqs.remove(seq));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final order = widget.order;
    final stops = order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;
    // Chỉ shop tự đánh dấu được khi đơn còn đang xử lý — đơn đã hoàn thành/
    // huỷ hoặc không phải đơn gộp thì không hiện nút (order.isBatch đã được
    // đảm bảo bởi nơi khởi tạo _StopsCard, kiểm tra lại ở đây cho chắc chắn).
    final canMarkDelivered =
        order.isBatch && _activeStatuses.contains(order.status);

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
          icon: Icons.route_rounded,
          label: 'Đơn gộp — $delivered/${stops.length} điểm đã giao',
          iconColor: c.success,
        ),
        const SizedBox(height: 12),

        ...stops.asMap().entries.map((e) {
          final i = e.key;
          final stop = e.value;
          final isDone = stop['delivered_at'] != null;
          final seq = (stop['seq'] as num).toInt();
          final fee = (stop['fee'] as num?)?.toInt();
          final phone = stop['phone'] as String? ?? '';
          final addr = stop['address'] as String? ?? '';
          final name = stop['name'] as String? ?? '';

          return Column(children: [
            if (i > 0) Divider(height: 16, color: c.divider),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sequence badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone ? c.success : c.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text('${stop['seq']}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDone ? Colors.white : c.primary)),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                      name.isNotEmpty ? name : 'Điểm ${stop['seq']}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDone ? c.textSecondary : c.textPrimary,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null),
                    )),
                    if (fee != null)
                      Text(Fmt.currency(fee),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDone ? c.textSecondary : c.primary)),
                  ]),
                  const SizedBox(height: 2),
                  Text(addr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () => callPhone(phone),
                      child: Row(children: [
                        Icon(Icons.phone_outlined, size: 12, color: c.primary),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: TextStyle(
                                fontSize: 12,
                                color: c.primary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  if (isDone) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Đã giao lúc ${_fmtTime(stop['delivered_at'] as String)}',
                      style: TextStyle(fontSize: 11, color: c.success),
                    ),
                  ] else if (canMarkDelivered) ...[
                    const SizedBox(height: 8),
                    _MarkDeliveredButton(
                      loading: _deliveringSeqs.contains(seq),
                      onTap: () => _markDelivered(seq),
                    ),
                  ],
                ],
              )),
            ]),
          ]);
        }),

        // Progress bar tổng
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stops.isEmpty ? 0 : delivered / stops.length,
            backgroundColor: c.surfaceAlt,
            color: c.success,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text('$delivered/${stops.length} điểm đã giao',
            style: TextStyle(fontSize: 11, color: c.textSecondary)),
      ]),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _MarkDeliveredButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _MarkDeliveredButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.primary, width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            SizedBox(
              width: 13,
              height: 13,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            )
          else
            Icon(Icons.check_rounded, size: 15, color: c.primary),
          const SizedBox(width: 6),
          Text('Đánh dấu đã giao',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
        ]),
      ),
    );
  }
}
