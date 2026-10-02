import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_decor_widgets.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../utils/order_reorder.dart';
import '../widgets/order_driver_row.dart';
import '../widgets/order_route_lines.dart';

final _filterProvider = StateProvider<String>((ref) => 'all');
final _searchQueryProvider = StateProvider<String>((ref) => '');

bool _matchesSearch(OrderModel order, String query) {
  if (query.isEmpty) return true;
  return order.code.toLowerCase().contains(query) ||
      order.deliveryPhone.toLowerCase().contains(query) ||
      order.receiverName?.toLowerCase().contains(query) == true;
}

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  static const _filters = [
    ('all', 'Tất cả'),
    ('pending', 'Chờ tài xế'),
    ('processing', 'Đang giao'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(_searchQueryProvider);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 300) {
        ref.read(orderListProvider.notifier).fetch();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(orderListProvider.notifier).fetch(refresh: true);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderListProvider);
    final filter = ref.watch(_filterProvider);
    final query = ref.watch(_searchQueryProvider).trim().toLowerCase();
    final all = state.orders;
    final c = context.colors;

    final counts = <String, int>{
      'all': all.length,
      'pending': all.where((o) => o.status == 'pending').length,
      'processing': all
          .where((o) => const ['assigned', 'processing'].contains(o.status))
          .length,
      'completed': all.where((o) => o.isCompleted).length,
      'cancelled': all.where((o) => o.isCancelled).length,
    };

    final displayed = switch (filter) {
      'pending' => all.where((o) => o.status == 'pending'),
      'processing' =>
        all.where((o) => const ['assigned', 'processing'].contains(o.status)),
      'completed' => all.where((o) => o.isCompleted),
      'cancelled' => all.where((o) => o.isCancelled),
      _ => all,
    }
        .where((o) => _matchesSearch(o, query))
        .toList();

    return ColoredBox(
      color: Colors.transparent,
      child: Column(children: [
        _OrderListHeader(
          controller: _searchCtrl,
          query: query,
          selectedFilter: filter,
          filters: _filters,
          counts: counts,
          loading: state.isLoading,
          onSearchChanged: (value) =>
              ref.read(_searchQueryProvider.notifier).state = value,
          onClearSearch: () {
            _searchCtrl.clear();
            ref.read(_searchQueryProvider.notifier).state = '';
          },
          onFilterChanged: (value) =>
              ref.read(_filterProvider.notifier).state = value,
          onCreate: () => context.push('/create-order'),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (displayed.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyContent(
                      loading: state.isLoading,
                      error: state.error,
                      filter: filter,
                      searching: query.isNotEmpty,
                      onReset: () {
                        _searchCtrl.clear();
                        ref.read(_searchQueryProvider.notifier).state = '';
                        ref.read(_filterProvider.notifier).state = 'all';
                      },
                      onRetry: _refresh,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                    sliver: SliverList.separated(
                      itemCount: displayed.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, index) => _OrderCard(
                        key: ValueKey(displayed[index].code),
                        order: displayed[index],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildLoadMore(state)),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoadMore(OrderListState state) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
        child: Column(children: [
          if (state.isLoading)
            const CircularProgressIndicator(strokeWidth: 2)
          else if (state.hasMore || state.error != null) ...[
            if (state.error != null) ...[
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: () => ref.read(orderListProvider.notifier).fetch(),
              icon: Icon(state.error != null
                  ? Icons.refresh_rounded
                  : Icons.expand_more_rounded),
              label:
                  Text(state.error != null ? 'Thử lại' : 'Tải thêm đơn hàng'),
            ),
          ],
        ]),
      );
}

class _OrderListHeader extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final String selectedFilter;
  final List<(String, String)> filters;
  final Map<String, int> counts;
  final bool loading;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onCreate;

  const _OrderListHeader({
    required this.controller,
    required this.query,
    required this.selectedFilter,
    required this.filters,
    required this.counts,
    required this.loading,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassHeader(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(children: [
        Row(children: [
          AppIconBadge(
              icon: Icons.receipt_long_rounded, color: c.primary, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn hàng',
                    style: AppTextStyles.screenTitle.copyWith(
                        color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xxs),
                Text('${counts['all'] ?? 0} đơn đã tải',
                    style:
                        AppTextStyles.label.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          // Nút tạo đơn: viên thuốc cam gradient, đổ bóng cam, kèm nhãn rõ nghĩa.
          Semantics(
            button: true,
            label: 'Tạo đơn mới',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryGradientEnd],
                ),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .55), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCreate,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md + 2, vertical: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: AppSize.iconMd),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Tạo đơn',
                          style: AppTextStyles.bodyStrong.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        AppField(
          controller: controller,
          hint: 'Tìm mã đơn, tên hoặc SĐT người nhận',
          fillColor: Colors.white.withValues(alpha: context.isDark ? .08 : .6),
          prefixIcon: Icon(Icons.search_rounded,
              size: AppSize.iconMd, color: c.textTertiary),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, index) {
              final filter = filters[index];
              final selected = selectedFilter == filter.$1;
              return Material(
                color: selected
                    ? c.primary
                    : Colors.white.withValues(alpha: context.isDark ? .08 : .6),
                shape: StadiumBorder(
                  side: BorderSide(
                      color: selected
                          ? c.primary
                          : Colors.white
                              .withValues(alpha: context.isDark ? .2 : .9),
                      width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onFilterChanged(filter.$1),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(children: [
                      Text(filter.$2,
                          style: AppTextStyles.label.copyWith(
                            color: selected ? Colors.white : c.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          )),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: .2)
                              : c.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text('${counts[filter.$1] ?? 0}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: AppFontSize.xs,
                              height: 1,
                              color: selected ? Colors.white : c.textTertiary,
                            )),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  Color _accent(Palette c) {
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    if (order.status == 'assigned') return c.info;
    return c.primary;
  }

  String _timeLabel() {
    final local = order.createdAt.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return Fmt.timeAgo(local);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = _accent(c);
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final delivery = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm giao · '
            '${order.stops.first['address'] ?? ''}'
        : order.deliveryAddress;
    final showDriver = order.driver != null &&
        (order.status == 'assigned' || order.status == 'processing');
    final canReorder = order.isCompleted || order.isCancelled;

    return GlassCard(
      blur: false,
      glow: order.isCancelled ? null : accent,
      onTap: () => context.push('/order/${order.code}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIconBadge(
            icon: order.isBatch
                ? Icons.call_split_rounded
                : Icons.inventory_2_rounded,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.isBatch ? 'Đơn gộp' : code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xxs),
                Text(order.isBatch ? '$code · ${_timeLabel()}' : _timeLabel(),
                    style: AppTextStyles.label.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.currency(order.shippingFee),
                style: AppTextStyles.sectionTitle.copyWith(color: accent)),
            const SizedBox(height: AppSpacing.xxs),
            _StatusPill(
              label: order.status == 'processing'
                  ? 'Đang giao'
                  : Fmt.orderStatus(order.status),
              color: accent,
            ),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: AppSpacing.md),
        OrderRouteLines(
          pickup: order.pickupAddress,
          delivery: delivery,
          dimmed: order.isCancelled,
        ),
        if (showDriver) ...[
          const SizedBox(height: AppSpacing.md),
          OrderDriverRow(driver: order.driver!),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Icon(Icons.payments_outlined,
              size: AppSize.iconSm, color: c.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              order.isCancelled
                  ? 'Đơn đã huỷ'
                  : 'Tiền lấy hàng ${Fmt.currency(order.codAmount ?? 0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
            ),
          ),
          if (canReorder)
            TextButton.icon(
              onPressed: () => reorderOrder(context, order),
              icon: const Icon(Icons.replay_rounded, size: AppSize.iconSm),
              label: const Text('Đặt lại'),
            )
          else ...[
            Text('Chi tiết',
                style: AppTextStyles.label
                    .copyWith(color: c.primary, fontWeight: FontWeight.w800)),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded,
                size: AppSize.iconMd, color: c.primary),
          ],
        ]),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w800)),
      );
}

class _EmptyContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final String filter;
  final bool searching;
  final VoidCallback onReset;
  final Future<void> Function() onRetry;

  const _EmptyContent({
    required this.loading,
    required this.error,
    required this.filter,
    required this.searching,
    required this.onReset,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: AppEmptyState(
            icon: Icons.cloud_off_rounded,
            title: error!,
            action: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
        ),
      );
    }

    final title = searching
        ? 'Không tìm thấy đơn phù hợp'
        : switch (filter) {
            'pending' => 'Không có đơn chờ tài xế',
            'processing' => 'Không có đơn đang giao',
            'completed' => 'Chưa có đơn hoàn thành',
            'cancelled' => 'Không có đơn đã huỷ',
            _ => 'Chưa có đơn hàng nào',
          };
    return Center(
      child: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: title,
        action: searching || filter != 'all'
            ? TextButton(onPressed: onReset, child: const Text('Xóa bộ lọc'))
            : null,
      ),
    );
  }
}
