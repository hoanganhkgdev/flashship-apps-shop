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
      child: Column(children: [
        _CompactInfoRow(label: 'Loại hàng', value: cargo.$2),
        const SizedBox(height: 10),
        _CompactInfoRow(
            label: 'Tiền thu hộ (COD)',
            value: Fmt.currency(order.codAmount ?? 0)),
        if (order.distanceKm != null) ...[
          const SizedBox(height: 10),
          _CompactInfoRow(
              label: 'Khoảng cách',
              value: '${order.distanceKm!.toStringAsFixed(1)} km'),
        ],
        if (order.nightSurcharge > 0) ...[
          const SizedBox(height: 10),
          _CompactInfoRow(
              label: 'Phụ thu đêm',
              value: '+${Fmt.currency(order.nightSurcharge)}'),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: c.divider),
        ),
        Row(children: [
          Text('Phí giao hàng',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const Spacer(),
          Text(Fmt.currency(order.shippingFee),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.primary)),
        ]),
      ]),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _CompactInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
      Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
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
            icon: Icons.notes_outlined,
            label: 'Ghi chú',
            iconColor: c.textSecondary),
        const SizedBox(height: 10),
        Text(note,
            style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.5)),
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
        const SizedBox(height: 10),
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
