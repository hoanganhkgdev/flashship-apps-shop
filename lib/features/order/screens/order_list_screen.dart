import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../utils/order_reorder.dart';

final _filterProvider = StateProvider<String>((ref) => 'all');
final _searchQueryProvider = StateProvider<String>((ref) => '');

bool _matchesSearch(OrderModel order, String query) {
  if (query.isEmpty) return true;
  return order.code.toLowerCase().contains(query) ||
      order.pickupAddress.toLowerCase().contains(query) ||
      order.deliveryAddress.toLowerCase().contains(query) ||
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
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(_searchQueryProvider);
    _searching = _searchCtrl.text.isNotEmpty;
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

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state = '';
    }
  }

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
      color: c.background,
      child: Column(children: [
        _OrderListHeader(
          controller: _searchCtrl,
          searching: _searching,
          query: query,
          selectedFilter: filter,
          filters: _filters,
          counts: counts,
          loading: state.isLoading,
          onToggleSearch: _toggleSearch,
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
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppBottomNav.reservedHeight(context) + 16,
        ),
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
  final bool searching;
  final String query;
  final String selectedFilter;
  final List<(String, String)> filters;
  final Map<String, int> counts;
  final bool loading;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onCreate;

  const _OrderListHeader({
    required this.controller,
    required this.searching,
    required this.query,
    required this.selectedFilter,
    required this.filters,
    required this.counts,
    required this.loading,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final headerColor =
        context.isDark ? c.primarySoft : const Color(0xFFFFE9DE);
    final filterHeight = 42 +
        (MediaQuery.textScalerOf(context).scale(12) - 12)
            .clamp(0.0, double.infinity);

    return DecoratedBox(
      decoration: BoxDecoration(color: headerColor),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Đơn '),
                          TextSpan(
                            text: 'hàng',
                            style: TextStyle(color: c.primary),
                          ),
                        ]),
                        style: AppTextStyles.screenTitle.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Theo dõi đơn và đặt lại khi cần',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading) ...[
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                _HeaderAction(
                  tooltip: 'Tạo đơn mới',
                  icon: Icons.add_rounded,
                  foreground: c.primary,
                  background: c.surface,
                  border: const Color(0xFFFFD1BF),
                  onTap: onCreate,
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  tooltip: searching ? 'Đóng tìm kiếm' : 'Tìm đơn',
                  icon: searching ? Icons.close_rounded : Icons.search_rounded,
                  foreground: Colors.white,
                  background: c.primary,
                  onTap: onToggleSearch,
                ),
              ]),
              if (searching) ...[
                const SizedBox(height: 12),
                AppField(
                  controller: controller,
                  hint: 'Tìm mã đơn, địa chỉ, tên hoặc SĐT',
                  fillColor: c.surface,
                  outlined: true,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: AppSize.iconMd,
                    color: c.textTertiary,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onChanged: onSearchChanged,
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: filterHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final filter = filters[index];
                    final selected = selectedFilter == filter.$1;
                    return ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => onFilterChanged(filter.$1),
                      avatar: selected
                          ? null
                          : Text(
                              '${counts[filter.$1] ?? 0}',
                              style: AppTextStyles.caption.copyWith(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      label: Text(
                        selected
                            ? '${filter.$2}  ${counts[filter.$1] ?? 0}'
                            : filter.$2,
                      ),
                      labelStyle: AppTextStyles.caption.copyWith(
                        color: selected ? Colors.white : c.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      selectedColor: c.primary,
                      backgroundColor: c.surface.withValues(alpha: .86),
                      side: BorderSide(
                        color: selected ? c.primary : const Color(0xFFFFD1BF),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color? border;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          foregroundColor: foreground,
          backgroundColor: background,
          side: border == null ? null : BorderSide(color: border!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 22),
      );
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({super.key, required this.order});

  String get _serviceTitle {
    if (order.isBatch) return 'Đơn gộp';
    return order.shopServiceType == 'shop_pickup' ? 'Lấy hàng' : 'Giao hàng';
  }

  String get _serviceAsset {
    if (order.isBatch) return 'assets/images/icon-batch.png';
    return order.shopServiceType == 'shop_pickup'
        ? 'assets/images/icon-pickup.png'
        : 'assets/images/icon-delivery.png';
  }

  String get _recipient {
    final name = order.receiverName?.trim() ?? '';
    final phone = order.deliveryPhone.trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    return order.isBatch ? '${order.stops.length} điểm giao' : 'Người nhận';
  }

  String get _deliveryAddress {
    if (!order.isBatch || order.stops.isEmpty) return order.deliveryAddress;
    final first = '${order.stops.first['address'] ?? order.deliveryAddress}';
    final remaining = order.stops.length - 1;
    return remaining > 0 ? '$first · và $remaining điểm khác' : first;
  }

  ({String label, Color color}) _status(Palette c) => switch (order.status) {
        'pending' => (label: 'Đang tìm tài xế', color: c.primary),
        'assigned' => (label: 'Tài xế đang đến', color: c.info),
        'processing' => (label: 'Đang giao', color: c.success),
        'completed' => (label: 'Hoàn thành', color: c.success),
        'cancelled' => (label: 'Đã huỷ', color: c.danger),
        _ => (label: Fmt.orderStatus(order.status), color: c.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = _status(c);
    final serviceColor = order.isBatch
        ? c.info
        : order.shopServiceType == 'shop_pickup'
            ? c.accent2
            : c.primary;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final canReorder = order.isCompleted || order.isCancelled;
    void open() => context.push('/order/${order.code}');

    return Semantics(
      button: true,
      label: '$_serviceTitle $code, ${status.label}',
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: serviceColor.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      _serviceAsset,
                      fit: BoxFit.contain,
                      cacheWidth: 132,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serviceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$code · ${Fmt.timeAgo(order.createdAt.toLocal())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.sizeOf(context).width < 360 ? 104 : 132,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: status.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    _RouteRow(
                      icon: Icons.radio_button_checked_rounded,
                      color: serviceColor,
                      label: 'Điểm lấy',
                      title: order.storeName?.trim().isNotEmpty == true
                          ? order.storeName!.trim()
                          : 'Cửa hàng',
                      address: order.pickupAddress,
                    ),
                    const SizedBox(height: 10),
                    _RouteRow(
                      icon: Icons.location_on_rounded,
                      color: c.danger,
                      label: order.isBatch ? 'Các điểm giao' : 'Điểm giao',
                      title: _recipient,
                      address: _deliveryAddress,
                    ),
                  ]),
                ),
                if (order.driver != null && order.isActive) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.person_rounded, size: 17, color: serviceColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tài xế: ${order.driver!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: c.divider),
                const SizedBox(height: 9),
                _OrderFooter(
                  order: order,
                  color: serviceColor,
                  canReorder: canReorder,
                  onOpen: open,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: c.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _OrderFooter extends StatelessWidget {
  final OrderModel order;
  final Color color;
  final bool canReorder;
  final VoidCallback onOpen;

  const _OrderFooter({
    required this.order,
    required this.color,
    required this.canReorder,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cod = order.codAmount ?? 0;
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cod > 0 ? 'Thu hộ ${Fmt.currency(cod)}' : 'Không thu hộ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          'Phí ship',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: c.textTertiary,
          ),
        ),
      ],
    );
    final fee = Text(
      Fmt.currency(order.shippingFee),
      maxLines: 1,
      textAlign: TextAlign.right,
      style: AppTextStyles.label.copyWith(
        color: c.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
    final action = TextButton.icon(
      onPressed: canReorder ? () => reorderOrder(context, order) : onOpen,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: .10),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: Icon(
        canReorder ? Icons.replay_rounded : Icons.arrow_forward_rounded,
        size: 16,
      ),
      label: Text(canReorder ? 'Đặt lại' : 'Chi tiết'),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(12) > 15;
      if (compact) {
        return Column(children: [
          Row(children: [
            Expanded(child: detail),
            const SizedBox(width: 10),
            fee,
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: action),
        ]);
      }
      return Row(children: [
        Expanded(child: detail),
        const SizedBox(width: 8),
        fee,
        const SizedBox(width: 10),
        action,
      ]);
    });
  }
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: title,
          subtitle: searching || filter != 'all'
              ? 'Thử thay đổi từ khoá hoặc bộ lọc trạng thái.'
              : 'Các đơn đã tạo sẽ xuất hiện tại đây.',
          action: searching || filter != 'all'
              ? TextButton(onPressed: onReset, child: const Text('Xóa bộ lọc'))
              : null,
        ),
      ),
    );
  }
}
