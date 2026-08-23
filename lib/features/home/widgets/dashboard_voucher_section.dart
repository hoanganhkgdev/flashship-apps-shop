part of '../screens/home_screen.dart';

// ─── Voucher Section ─────────────────────────────────────────────────────────

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voucherProvider);
    final c = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (vouchers) {
        if (vouchers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_offer_rounded,
                      size: 15, color: c.success),
                ),
                const SizedBox(width: 8),
                Text('Mã giảm giá',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${vouchers.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ]),
            ),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: vouchers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final v = vouchers[i];
                  return SizedBox(
                    width: 200,
                    child: VoucherCard(
                      voucher: v,
                      eligible: !(v.isExpired || v.isFull),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: v.code));
                        AppSnackbar.success(context, 'Đã sao chép: ${v.code}',
                            duration: const Duration(seconds: 2));
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: c.cardShadow),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: c.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('Chưa có đơn nào đang chạy',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Chọn dịch vụ bên trên để tạo đơn mới',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
