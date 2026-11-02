part of '../screens/home_screen.dart';

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider);
    final activeOrders = orders.orders
        .where((order) =>
            order.status == 'pending' ||
            order.status == 'assigned' ||
            order.status == 'processing')
        .toList();
    const statusPriority = {'pending': 0, 'assigned': 1, 'processing': 2};
    activeOrders.sort((a, b) => (statusPriority[a.status] ?? 9)
        .compareTo(statusPriority[b.status] ?? 9));
    final todayAsync = ref.watch(todayStatsProvider);
    final c = context.colors;

    Future<void> refresh() async {
      final ordersRefresh =
          ref.read(orderListProvider.notifier).fetch(refresh: true);
      final addressesRefresh = ref.read(addressProvider.notifier).fetch();
      ref.invalidate(todayStatsProvider);
      ref.invalidate(supportConfigProvider);
      await Future.wait([
        ordersRefresh,
        addressesRefresh,
        ref.read(todayStatsProvider.future),
        ref.read(supportConfigProvider.future),
      ]);
    }

    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _Header(
              shopName: user?.name ?? 'Cửa hàng',
              shopAddress: user?.address ?? '',
            ),
            const SliverToBoxAdapter(child: _SoftUpdateBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: CreateOrderCard(
                  onDeliveryTap: () => context.push('/create-order',
                      extra: ShopOrderType.delivery),
                  onPickupTap: () => context.push('/create-order',
                      extra: ShopOrderType.pickup),
                  onBatchTap: () => context.push('/create-batch'),
                ),
              ),
            ),
            if (orders.isLoading && orders.orders.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl2),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (orders.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _HomeErrorCard(
                    message: orders.error!,
                    onRetry: refresh,
                  ),
                ),
              ),
            if (activeOrders.isNotEmpty)
              _HomeOrderSection(
                title: 'Đơn đang thực hiện',
                subtitle: 'Theo dõi trạng thái các đơn của shop',
                orders: activeOrders,
                limit: 3,
                onViewAll: () => ref.read(_tabProvider.notifier).state = 1,
              ),
            if (!orders.isLoading &&
                orders.error == null &&
                activeOrders.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _EmptyOrders(
                    firstOrder: orders.orders.isEmpty && !orders.hasMore,
                    hasMore: orders.hasMore,
                    onViewOrders: () =>
                        ref.read(_tabProvider.notifier).state = 1,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShopHomeSectionHeading(
                    title: 'Hôm nay của shop',
                    highlight: 'của shop',
                    subtitle: 'Tổng quan hoạt động trong ngày',
                    subtitleIcon: Icons.insights_rounded,
                    actionLabel: 'Chi tiết',
                    onAction: () => ref.read(_tabProvider.notifier).state = 2,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: todayAsync.when(
                      data: (stats) => _TodayOverviewCard(
                        stats: stats,
                        loading: false,
                        onTap: () => ref.read(_tabProvider.notifier).state = 2,
                      ),
                      loading: () => _TodayOverviewCard(
                        stats: const TodayStats(),
                        loading: true,
                        onTap: () => ref.read(_tabProvider.notifier).state = 2,
                      ),
                      error: (_, __) => _HomeErrorCard(
                        message: 'Chưa tải được thống kê hôm nay',
                        onRetry: () async {
                          ref.invalidate(todayStatsProvider);
                          await ref.read(todayStatsProvider.future);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: _QuickReorderSection()),
            const SliverToBoxAdapter(child: _FrequentAddressSection()),
            const SliverToBoxAdapter(child: _VoucherSection()),
            const SliverToBoxAdapter(child: _HomeSupportSection()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppBottomNav.reservedHeight(context) + 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _HomeErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.warning.withValues(alpha: .2)),
      ),
      child: Row(children: [
        AppIconBadge(icon: Icons.cloud_off_rounded, color: c.warning, size: 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: c.textSecondary)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ]),
    );
  }
}

/// Một nhóm đơn đang thực hiện, ưu tiên các đơn cần shop xử lý trước.
class _HomeOrderSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<OrderModel> orders;
  final int limit;
  final VoidCallback onViewAll;

  const _HomeOrderSection({
    required this.title,
    this.subtitle,
    required this.orders,
    required this.limit,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(slivers: [
        SliverToBoxAdapter(
          child: ShopHomeSectionHeading(
            title: title,
            highlight: 'đang thực hiện',
            subtitle: subtitle,
            subtitleIcon: Icons.route_rounded,
            actionLabel: 'Xem tất cả',
            onAction: onViewAll,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: orders.length.clamp(0, limit),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _OrderCard(
              key: ValueKey(orders[index].code),
              order: orders[index],
            ),
          ),
        ),
      ]);
}
