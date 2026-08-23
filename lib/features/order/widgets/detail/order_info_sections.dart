part of '../../screens/order_detail_screen.dart';

// ─── Order Info Card ──────────────────────────────────────────────────────────

class _OrderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _OrderInfoCard({required this.order});

  static const _cargoInfo = {
    'food': (Icons.lunch_dining_rounded, 'Đồ ăn', Color(0xFFF59E0B)),
    'flowers': (
      Icons.local_florist_rounded,
      'Hoa / Trái cây',
      Color(0xFFEC4899)
    ),
    'parcel': (Icons.inventory_2_rounded, 'Bưu kiện', Color(0xFF6B7280)),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cargo = _cargoInfo[order.cargoType] ??
        (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.receipt_long_outlined,
            label: 'Thông tin đơn hàng',
            iconColor: c.primary),
        const SizedBox(height: 12),

        // Cargo badge + code
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cargo.$3.withValues(alpha: context.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cargo.$1, color: cargo.$3, size: 14),
              const SizedBox(width: 6),
              Text(cargo.$2,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cargo.$3)),
              if (order.cargoWeight != null) ...[
                const SizedBox(width: 4),
                Text(
                    '• ${order.cargoWeight!.toStringAsFixed(order.cargoWeight! % 1 == 0 ? 0 : 1)}kg',
                    style: TextStyle(fontSize: 11, color: cargo.$3)),
              ],
            ]),
          ),
          const Spacer(),
          Text('#${order.code}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
        ]),

        const SizedBox(height: 12),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 12),

        if (order.distanceKm != null) ...[
          _InfoRow(Icons.straighten_rounded, 'Khoảng cách',
              '${order.distanceKm!.toStringAsFixed(1)} km'),
          const SizedBox(height: 8),
        ],

        if (order.nightSurcharge > 0) ...[
          _InfoRow(Icons.nightlight_round, 'Phụ thu đêm',
              '+ ${Fmt.currency(order.nightSurcharge)}',
              valueColor: c.warning),
          const SizedBox(height: 8),
        ],

        // Fee highlight
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.primary.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            Icon(Icons.payments_outlined, size: 18, color: c.primary),
            const SizedBox(width: 10),
            Text('Phí vận chuyển',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
            const Spacer(),
            Text(Fmt.currency(order.shippingFee),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.primary)),
          ]),
        ),

        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _InfoRow(Icons.account_balance_wallet_outlined, 'Thu hộ COD',
              Fmt.currency(order.codAmount!),
              valueColor: c.info),
        ],

        const SizedBox(height: 12),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 12),

        _InfoRow(Icons.credit_card_outlined, 'Thanh toán', 'Tiền mặt'),
        const SizedBox(height: 8),
        _InfoRow(Icons.access_time_outlined, 'Thời gian',
            Fmt.dateTime(order.createdAt)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? c.textPrimary)),
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
