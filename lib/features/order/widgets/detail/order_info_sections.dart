part of '../../screens/order_detail_screen.dart';

// ─── Order Info Card ──────────────────────────────────────────────────────────

class _OrderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _OrderInfoCard({required this.order});

  static const _cargoInfo = {
    'food': (Icons.lunch_dining_rounded, 'Thực phẩm', Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded, 'Giỏ hoa', Color(0xFFEC4899)),
    'parcel': (Icons.inventory_2_rounded, 'Kiện hàng', Color(0xFF6B7280)),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cargo = _cargoInfo[order.cargoType] ??
        (Icons.inventory_2_rounded, 'Kiện hàng', const Color(0xFF6B7280));

    return _FlatCard(
      glow: c.primary,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.receipt_long_rounded,
            label: 'Chi tiết đơn',
            iconColor: c.primary),
        const SizedBox(height: AppSpacing.lg),
        _CompactInfoRow(
            icon: cargo.$1,
            iconColor: cargo.$3,
            label: 'Loại hàng',
            value: cargo.$2),
        if (order.distanceKm != null) ...[
          const SizedBox(height: AppSpacing.md),
          _CompactInfoRow(
              icon: Icons.straighten_rounded,
              label: 'Khoảng cách',
              value: '${order.distanceKm!.toStringAsFixed(1)} km'),
        ],
        if (order.nightSurcharge > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _CompactInfoRow(
              icon: Icons.nights_stay_outlined,
              label: 'Phụ thu đêm',
              value: '+${Fmt.currency(order.nightSurcharge)}'),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Text('Phí giao hàng',
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
            const Spacer(),
            Text(Fmt.currency(order.shippingFee),
                style: AppTextStyles.metric.copyWith(color: c.primary)),
          ]),
        ),
      ]),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  const _CompactInfoRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: AppSize.iconMd, color: iconColor ?? c.textTertiary),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(label,
            style: AppTextStyles.body.copyWith(color: c.textSecondary)),
      ),
      Text(value,
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
    ]);
  }
}

// Giữ row có icon cho các section phụ (ghi chú/đánh giá) khi cần mở rộng.
// ignore: unused_element
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: 15, color: c.textSecondary),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(fontSize: AppFontSize.base, color: c.textSecondary)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: AppFontSize.base,
              fontWeight: FontWeight.w600,
              color: c.textPrimary)),
    ]);
  }
}

// ─── Note Card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.notes_outlined, label: 'Ghi chú', iconColor: c.accent2),
        const SizedBox(height: AppSpacing.md),
        Text(note,
            style:
                AppTextStyles.body.copyWith(color: c.textPrimary, height: 1.5)),
      ]),
    );
  }
}

// ─── Rating Display ───────────────────────────────────────────────────────────

class _RatingDisplay extends StatelessWidget {
  final int rating;
  const _RatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.star_rounded,
            label: 'Đánh giá của bạn',
            iconColor: c.warning),
        const SizedBox(height: AppSpacing.md),
        Row(
            children: List.generate(
                5,
                (i) => Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: c.warning,
                      size: 28,
                    ))),
      ]),
    );
  }
}
