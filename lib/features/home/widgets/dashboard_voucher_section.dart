part of '../screens/home_screen.dart';

// ─── Voucher Section ─────────────────────────────────────────────────────────
// Banner phẳng, viền đứt tông accent2 — gọn hơn VoucherCard (dải trái +
// OFF) dùng ở sheet chọn mã trong màn tạo đơn, phù hợp làm điểm nhấn
// khuyến mãi ở trang chủ thay vì nơi cần so sánh nhiều mã cùng lúc.

// Voucher vẫn được giữ để có thể tái sử dụng ở chiến dịch khuyến mãi sau này.
// ignore: unused_element
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              for (final v in eligible.take(1)) ...[
                _VoucherBanner(
                  voucher: v,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v.code));
                    AppSnackbar.success(context, 'Đã sao chép: ${v.code}',
                        duration: const Duration(seconds: 2));
                  },
                ),
              ],
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.accent2Soft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              Border.all(color: c.accent2.withValues(alpha: 0.4), width: 1.2),
        ),
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
                Text(_subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppFontSize.sm, color: c.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: c.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.glassBorder, width: 1.2),
          boxShadow: context.isDark ? null : AppShadows.soft,
        ),
        child: Column(children: [
          AppIconBadge(
              icon: Icons.inventory_2_outlined,
              color: c.textSecondary,
              size: 56),
          const SizedBox(height: AppSpacing.md),
          Text('Chưa có đơn hàng nào',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Chọn loại đơn ở trên để tạo đơn đầu tiên',
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
