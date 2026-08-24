part of '../screens/home_screen.dart';

// ─── Dashboard Tab ───────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider);
    final recent = orders.orders;
    final todayAsync = ref.watch(todayStatsProvider);
    final c = context.colors;

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: CreateOrderCard(
                  onDeliveryTap: () => context.push('/create-order',
                      extra: ShopOrderType.delivery),
                  onPickupTap: () => context.push('/create-order',
                      extra: ShopOrderType.pickup),
                  onBatchTap: () => context.push('/create-batch'),
                ),
              ),
            ),

            // ── Voucher — đưa lên ngay dưới khối thao tác, đồng bộ vị trí
            // nổi bật trong mockup thay vì chôn dưới cùng như trước ────────
            const SliverToBoxAdapter(child: _VoucherSection()),

            // ── Đơn gần đây ───────────────────────────────────────────────
            if (recent.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(children: [
                    Expanded(
                      child: Text('Đơn gần đây',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(_tabProvider.notifier).state = 1,
                      child: Text('Xem tất cả',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.primary)),
                    ),
                  ]),
                ),
              ),
              // Mỗi đơn 1 thẻ trắng shadow riêng, cách nhau bằng khoảng trắng
              // — đồng bộ ActiveOrderCard/CompletedOrderCard app driver, thay
              // vì gộp chung 1 khối lớn ngăn bằng Divider như trước.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: recent.take(3).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = recent[i];
                    return _OrderCard(key: ValueKey(order.code), order: order);
                  },
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(child: _EmptyOrders()),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
