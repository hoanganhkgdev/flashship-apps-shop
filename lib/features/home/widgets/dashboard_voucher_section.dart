part of '../screens/home_screen.dart';

// ─── Voucher Section ─────────────────────────────────────────────────────────
// Banner phẳng, viền đứt tông accent2 — gọn hơn VoucherCard (dải trái +
// OFF) dùng ở sheet chọn mã trong màn tạo đơn, phù hợp làm điểm nhấn
// khuyến mãi ở trang chủ thay vì nơi cần so sánh nhiều mã cùng lúc.

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voucherProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (vouchers) {
        final eligible =
            vouchers.where((v) => !(v.isExpired || v.isFull)).toList();
        if (eligible.isEmpty) return const SizedBox.shrink();
        final voucher = eligible.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShopHomeSectionHeading(
              title: 'Ưu đãi của shop',
              highlight: 'của shop',
              subtitle: 'Mã giảm giá đang có',
              subtitleIcon: Icons.confirmation_number_rounded,
              actionLabel: eligible.length > 1 ? 'Xem tất cả' : null,
              onAction:
                  eligible.length > 1 ? () => context.push('/vouchers') : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _VoucherBanner(
                voucher: voucher,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: voucher.code));
                  AppSnackbar.success(context, 'Đã sao chép: ${voucher.code}',
                      duration: const Duration(seconds: 2));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VoucherBanner extends StatelessWidget {
  final VoucherModel voucher;
  final VoidCallback onTap;
  const _VoucherBanner({required this.voucher, required this.onTap});

  String get _subtitle {
    final parts = <String>[
      if (voucher.minOrderValue != null)
        'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}'
      else
        voucher.description ?? 'Mã: ${voucher.code}',
      if (voucher.expiresAt != null) 'HSD ${VoucherCard.expiryText(voucher)}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.accent2Soft,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.accent2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voucher.discountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w700,
                          color: c.accent2)),
                  const SizedBox(height: 2),
                  Text(voucher.code,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSize.sm, color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 18, color: c.accent2),
          ]),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  final bool firstOrder;
  final bool hasMore;
  final VoidCallback onViewOrders;

  const _EmptyOrders({
    required this.firstOrder,
    required this.hasMore,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: Column(children: [
          AppIconBadge(
              icon: Icons.inventory_2_outlined,
              color: c.textSecondary,
              size: 56),
          const SizedBox(height: AppSpacing.md),
          Text(
              firstOrder
                  ? 'Sẵn sàng cho đơn đầu tiên'
                  : hasMore
                      ? 'Theo dõi các đơn của shop'
                      : 'Các đơn của shop đã xử lý xong',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
              firstOrder
                  ? 'Chọn dịch vụ ở trên để bắt đầu gửi hàng.'
                  : hasMore
                      ? 'Mở danh sách đơn để xem thêm các đơn trước đó.'
                      : 'Tạo đơn mới hoặc gửi lại cho khách quen ở bên dưới.',
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onViewOrders,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Xem tất cả đơn hàng'),
          ),
        ]),
      ),
    );
  }
}
