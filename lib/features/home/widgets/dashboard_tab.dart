part of '../screens/home_screen.dart';

// ─── Dashboard Tab ───────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider);
    final active = orders.active;
    final todayAsync = ref.watch(todayStatsProvider);
    final c = context.colors;

    // Số đang chạy THẬT lấy từ server (không giới hạn theo trang đã tải) —
    // active.length chỉ đếm được trong số đơn đã load về máy, thiếu nếu còn
    // đơn active nằm ở trang chưa tải. Cùng nguồn với badge trên header.
    final trueActiveCount = todayAsync.valueOrNull?.active ?? active.length;

    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: () async {
          ref.read(orderListProvider.notifier).fetch(refresh: true);
          ref.invalidate(todayStatsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                shopName: user?.name ?? 'Cửa hàng',
                shopAddress: user?.address ?? user?.phone ?? '',
                today: todayAsync.valueOrNull,
              ),
            ),

            // ── Banner nhắc cập nhật (không bắt buộc) ─────────────────────
            const SliverToBoxAdapter(child: _SoftUpdateBanner()),

            // ── Dịch vụ — thẻ trắng shadow chứa các ô thao tác màu, đồng bộ
            // khối "Tài chính" của app driver ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: CreateOrderCard(
                  onDeliveryTap: () => context.push('/create-order',
                      extra: ShopOrderType.delivery),
                  onPickupTap: () => context.push('/create-order',
                      extra: ShopOrderType.pickup),
                  onBatchTap: () => context.push('/create-batch'),
                ),
              ),
            ),

            // ── Active orders ────────────────────────────────────────────
            if (trueActiveCount > 0) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(children: [
                    Text('Đang chạy',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$trueActiveCount',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                ),
              ),
              // Mỗi đơn 1 thẻ trắng shadow riêng, cách nhau bằng khoảng trắng
              // — đồng bộ ActiveOrderCard/CompletedOrderCard app driver, thay
              // vì gộp chung 1 khối lớn ngăn bằng Divider như trước.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: active.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = active[i];
                    return _OrderCard(key: ValueKey(order.code), order: order);
                  },
                ),
              ),
              if (trueActiveCount > 5)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => ref.read(_tabProvider.notifier).state = 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Xem tất cả $trueActiveCount đơn đang chạy',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.primary),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 14, color: c.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ] else ...[
              SliverToBoxAdapter(child: _EmptyOrders()),
            ],

            // ── Banner thông báo/khuyến mãi (không phải ưu tiên chính) ────
            const SliverToBoxAdapter(child: _HomeBannerSection()),

            // ── Địa chỉ thường dùng ───────────────────────────────────────
            const SliverToBoxAdapter(child: _FrequentAddressSection()),

            // ── Voucher section ──────────────────────────────────────────
            const SliverToBoxAdapter(child: _VoucherSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
