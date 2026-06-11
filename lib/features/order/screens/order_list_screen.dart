import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

final _filterProvider = StateProvider<String>((ref) => 'all');
final _searchProvider = StateProvider<String>((ref) => '');

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  static const _filters = [
    ('all',       'Tất cả'),
    ('active',    'Đang chạy'),
    ('food',      'Đồ ăn'),
    ('flowers',   'Hoa'),
    ('parcel',    'Bưu kiện'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  static const _activeStatuses = ['pending', 'assigned', 'processing', 'on_the_way'];

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(orderListProvider);
    final loading = state.isLoading;
    final filter  = ref.watch(_filterProvider);
    final search  = ref.watch(_searchProvider);
    final all     = state.orders;

    final filtered = switch (filter) {
      'all'       => all,
      'active'    => all.where((o) => _activeStatuses.contains(o.status)).toList(),
      'completed' => all.where((o) => o.isCompleted).toList(),
      'cancelled' => all.where((o) => o.isCancelled).toList(),
      _           => all.where((o) => o.cargoType == filter).toList(),
    };

    final q = search.trim().toLowerCase();
    final displayed = q.isEmpty ? filtered : filtered.where((o) =>
      o.code.toLowerCase().contains(q) ||
      o.deliveryPhone.contains(q) ||
      (o.receiverName?.toLowerCase().contains(q) ?? false) ||
      o.deliveryAddress.toLowerCase().contains(q) ||
      (o.pickupPhone?.contains(q) ?? false) ||
      (o.senderName?.toLowerCase().contains(q) ?? false)
    ).toList();

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Đơn hàng',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    if (loading)
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 12),

                  // Filter chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final (key, label) = _filters[i];
                        final selected = filter == key;
                        return GestureDetector(
                          onTap: () =>
                              ref.read(_filterProvider.notifier).state = key,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textSecondary)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Search bar ────────────────────────────────────────
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        ref.read(_searchProvider.notifier).state = v,
                    style: const TextStyle(fontSize: 14,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo SĐT, tên, mã đơn...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textSecondary),
                      suffixIcon: search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(_searchProvider.notifier).state = '';
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                ],
              ),
            ),

            // ── Status summary khi lọc "Đang chạy" ────────────────────
            if (filter == 'active' && filtered.isNotEmpty)
              _ActiveSummary(orders: filtered),

            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: loading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
                  : displayed.isEmpty
                      ? _EmptyState(filter: filter, hasSearch: q.isNotEmpty)
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => ref
                              .read(orderListProvider.notifier)
                              .fetch(refresh: true),
                          child: ListView(
                            padding: const EdgeInsets.only(top: 8, bottom: 32),
                            children: [
                              Container(
                                color: Colors.white,
                                child: Column(
                                  children: displayed.asMap().entries.map((e) {
                                    final i = e.key;
                                    return Column(children: [
                                      _OrderTile(order: e.value),
                                      if (i < displayed.length - 1)
                                        const Divider(height: 1, indent: 60,
                                            color: Color(0xFFF5F5F5)),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active status summary ─────────────────────────────────────────────────────

class _ActiveSummary extends StatelessWidget {
  final List<OrderModel> orders;
  const _ActiveSummary({required this.orders});

  static const _steps = [
    ('pending',    'Chờ tài xế', Color(0xFFF59E0B)),
    ('assigned',   'Đã nhận',    AppColors.primary),
    ('processing', 'Đang lấy',   Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = {for (final (s, _, __) in _steps)
      s: orders.where((o) => o.status == s).length
    };
    final nonZero = _steps.where((s) => (counts[s.$1] ?? 0) > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: nonZero.map((item) {
          final (key, label, color) = item;
          final count = counts[key] ?? 0;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text('$count',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.85))),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Order Tile ───────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  static const _cargoInfo = {
    'food':    (Icons.lunch_dining_rounded,  'Đồ ăn',          Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded, 'Hoa / Trái cây', Color(0xFFEC4899)),
    'parcel':  (Icons.inventory_2_rounded,   'Bưu kiện',       Color(0xFF6B7280)),
  };

  Color _statusColor() {
    if (order.isCompleted) return AppColors.success;
    if (order.isCancelled) return AppColors.danger;
    if (order.status == 'pending') return const Color(0xFFF59E0B);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cargo       = _cargoInfo[order.cargoType]
        ?? (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));
    final statusColor = _statusColor();

    return InkWell(
      onTap: () => context.push('/order/${order.code}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Row(children: [
                    Text(cargo.$2,
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (order.isBatch) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${order.stops.length} điểm',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: AppColors.success),
                        ),
                      ),
                    ],
                  ])),
                  Text(Fmt.currency(order.shippingFee),
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 3),
                Text(order.isBatch && order.stops.isNotEmpty
                    ? '${order.stops.length} điểm: ${order.stops.first['address'] ?? ''}'
                    : order.deliveryAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(order.deliveryPhone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(Fmt.orderStatus(order.status),
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  const Spacer(),
                  Text(Fmt.timeAgo(order.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ],
            ),
          ),
        ]),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  final bool   hasSearch;
  const _EmptyState({required this.filter, this.hasSearch = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 52,
              color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'Không tìm thấy đơn phù hợp'
                : filter == 'active'
                    ? 'Không có đơn đang chạy'
                    : filter == 'all'
                        ? 'Chưa có đơn hàng nào'
                        : 'Không có đơn phù hợp',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ]),
      );
}
