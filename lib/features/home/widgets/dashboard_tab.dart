part of '../screens/home_screen.dart';

// ─── Dashboard Tab ───────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider);
    final active = orders.orders.where((order) => order.isActive).toList();
    final todayAsync = ref.watch(todayStatsProvider);
    final c = context.colors;

    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: () async {
          final ordersRefresh =
              ref.read(orderListProvider.notifier).fetch(refresh: true);
          ref.invalidate(todayStatsProvider);
          await Future.wait(
              [ordersRefresh, ref.read(todayStatsProvider.future)]);
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: CreateOrderCard(
                  onDeliveryTap: () => context.push('/create-order',
                      extra: ShopOrderType.delivery),
                  onPickupTap: () => context.push('/create-order',
                      extra: ShopOrderType.pickup),
                  onBatchTap: () => context.push('/create-batch'),
                ),
              ),
            ),

            // ── Đơn đang hoạt động ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                child: Row(children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 21, color: c.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đơn đang hoạt động',
                        style: TextStyle(
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text('${active.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: AppFontSize.base,
                            fontWeight: FontWeight.w800,
                            color: c.info)),
                  ),
                ]),
              ),
            ),
            if (active.isNotEmpty) ...[
              // Mỗi đơn 1 thẻ trắng shadow riêng, cách nhau bằng khoảng trắng
              // — đồng bộ ActiveOrderCard/CompletedOrderCard app driver, thay
              // vì gộp chung 1 khối lớn ngăn bằng Divider như trước.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: active.take(3).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = active[i];
                    return _OrderCard(key: ValueKey(order.code), order: order);
                  },
                ),
              ),
            ] else if (orders.isLoading) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ] else if (orders.error != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    Text(orders.error!, textAlign: TextAlign.center),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(orderListProvider.notifier)
                          .fetch(refresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ]),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(child: _EmptyOrders()),
            ],

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: OutlinedButton(
                  onPressed: () => ref.read(_tabProvider.notifier).state = 1,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Xem tất cả đơn hàng',
                          style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w800)),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
