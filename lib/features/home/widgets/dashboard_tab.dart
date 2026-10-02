part of '../screens/home_screen.dart';

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider);
    final active = orders.orders.where((order) => order.isActive).toList();
    final todayAsync = ref.watch(todayStatsProvider);
    final c = context.colors;

    Future<void> refresh() async {
      final ordersRefresh =
          ref.read(orderListProvider.notifier).fetch(refresh: true);
      ref.invalidate(todayStatsProvider);
      await Future.wait([ordersRefresh, ref.read(todayStatsProvider.future)]);
    }

    return ColoredBox(
      color: Colors.transparent,
      child: Column(children: [
        _Header(
          shopName: user?.name ?? 'Cửa hàng',
          shopAddress: user?.address ?? user?.phone ?? '',
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _SoftUpdateBanner()),

                // Hành động tạo đơn là nhu cầu chính của chủ shop.
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

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                    child: _TodayOverviewCard(
                      stats: todayAsync.valueOrNull ?? const TodayStats(),
                      loading: todayAsync.isLoading,
                      onTap: () => ref.read(_tabProvider.notifier).state = 2,
                    ),
                  ),
                ),

                if (active.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      icon: Icons.local_shipping_rounded,
                      title: 'Đơn đang giao (${active.length})',
                      actionLabel: 'Xem tất cả',
                      onAction: () => ref.read(_tabProvider.notifier).state = 1,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, 0),
                    sliver: SliverList.separated(
                      itemCount: active.take(3).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _OrderCard(
                          key: ValueKey(active[i].code), order: active[i]),
                    ),
                  ),
                ] else if (orders.isLoading) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl2),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                ] else if (orders.error != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                      child: _HomeErrorCard(
                        message: orders.error!,
                        onRetry: refresh,
                      ),
                    ),
                  ),
                ] else if (orders.orders.isEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: _EmptyOrders(),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: _QuickReorderSection()),
                const SliverToBoxAdapter(child: _FrequentAddressSection()),
                const SliverToBoxAdapter(child: _VoucherSection()),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl3),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(_tabProvider.notifier).state = 1,
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Xem tất cả đơn hàng'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
      child: Row(children: [
        AppIconBadge(icon: icon, color: c.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Text(actionLabel!,
                style: AppTextStyles.label.copyWith(color: c.primary)),
          ),
      ]),
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
