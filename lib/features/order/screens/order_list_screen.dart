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
    final c       = context.colors;

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
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Container(
            color: c.surface,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + loader
                  Row(children: [
                    Text('Đơn hàng',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const Spacer(),
                    if (loading)
                      SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: c.primary)),
                  ]),
                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          ref.read(_searchProvider.notifier).state = v,
                      style: TextStyle(fontSize: 14, color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Tìm SĐT, tên, mã đơn...',
                        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: c.textSecondary),
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.cancel_rounded,
                                    size: 16, color: c.textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref.read(_searchProvider.notifier).state = '';
                                },
                              )
                            : null,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
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
                              color: selected ? c.primary : c.background,
                              borderRadius: BorderRadius.circular(20),
                              border: selected
                                  ? null
                                  : Border.all(color: c.divider),
                            ),
                            child: Center(
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? c.onPrimary
                                          : c.textSecondary)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: loading && all.isEmpty
                  ? Center(child: CircularProgressIndicator(
                      color: c.primary, strokeWidth: 2))
                  : displayed.isEmpty
                      ? _EmptyState(filter: filter, hasSearch: q.isNotEmpty)
                      : RefreshIndicator(
                          color: c.primary,
                          onRefresh: () => ref
                              .read(orderListProvider.notifier)
                              .fetch(refresh: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            itemCount: displayed.length +
                                (filter == 'active' && filtered.isNotEmpty ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              // Active summary as first item
                              if (filter == 'active' &&
                                  filtered.isNotEmpty &&
                                  i == 0) {
                                return _ActiveSummary(orders: filtered);
                              }
                              final orderIdx = filter == 'active' &&
                                      filtered.isNotEmpty
                                  ? i - 1
                                  : i;
                              return _OrderCard(order: displayed[orderIdx]);
                            },
                          ),
                        ),
            ),
          ],
        ),
    );
  }
}

// ── Active status summary ─────────────────────────────────────────────────────

class _ActiveSummary extends StatelessWidget {
  final List<OrderModel> orders;
  const _ActiveSummary({required this.orders});

  static List<(String, String, Color)> _steps(Palette c) => [
        ('pending',    'Chờ tài xế', c.warning),
        ('assigned',   'Đã nhận',    c.primary),
        ('processing', 'Đang lấy',   const Color(0xFF8B5CF6)),
        ('on_the_way', 'Đang giao',  c.success),
      ];

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final steps = _steps(c);
    final counts = {for (final (s, _, _) in steps)
      s: orders.where((o) => o.status == s).length
    };
    final nonZero = steps.where((s) => (counts[s.$1] ?? 0) > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        children: nonZero.map((item) {
          final (key, label, color) = item;
          final count = counts[key] ?? 0;
          return Expanded(
            child: Column(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(
                      alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w800, color: color)),
                ),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  static const _cargoMeta = {
    'food':    (Icons.lunch_dining_rounded,  'Đồ ăn',          Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded, 'Hoa / Trái cây', Color(0xFFEC4899)),
    'parcel':  (Icons.inventory_2_rounded,   'Bưu kiện',       Color(0xFF6B7280)),
  };

  Color _statusColor(Palette c) {
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    return c.primary;
  }

  @override
  Widget build(BuildContext context) {
    final c           = context.colors;
    final cargo       = _cargoMeta[order.cargoType]
        ?? (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));
    final statusColor = _statusColor(c);
    final address     = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm · ${order.stops.first['address'] ?? ''}'
        : order.deliveryAddress;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: c.cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Cargo icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: cargo.$3.withValues(
                    alpha: context.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cargo.$1, color: cargo.$3, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: cargo label + batch badge + fee
                  Row(children: [
                    Text(cargo.$2,
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    if (order.isBatch) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.successSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${order.stops.length} điểm',
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c.success)),
                      ),
                    ],
                    const Spacer(),
                    Text(Fmt.currency(order.shippingFee),
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.primary)),
                  ]),
                  const SizedBox(height: 4),

                  // Row 2: receiver name + phone
                  Row(children: [
                    if (order.receiverName?.isNotEmpty == true) ...[
                      Flexible(
                        child: Text(order.receiverName!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary)),
                      ),
                      Text(' · ',
                          style: TextStyle(fontSize: 13,
                              color: c.textTertiary)),
                    ],
                    Text(order.deliveryPhone,
                        style: TextStyle(fontSize: 13,
                            color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 3),

                  // Row 3: address
                  Text(address,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12,
                          color: c.textSecondary)),
                  const SizedBox(height: 8),

                  // Row 4: status badge + time
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                            alpha: context.isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(Fmt.orderStatus(order.status),
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor)),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time_rounded,
                        size: 12, color: c.textTertiary),
                    const SizedBox(width: 3),
                    Text(Fmt.timeAgo(order.createdAt),
                        style: TextStyle(fontSize: 12,
                            color: c.textSecondary)),
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            hasSearch ? Icons.search_off_rounded : Icons.receipt_long_outlined,
            size: 34, color: c.textTertiary),
        ),
        const SizedBox(height: 14),
        Text(
          hasSearch
              ? 'Không tìm thấy đơn phù hợp'
              : filter == 'active'
                  ? 'Không có đơn đang chạy'
                  : filter == 'all'
                      ? 'Chưa có đơn hàng nào'
                      : 'Không có đơn phù hợp',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: c.textSecondary),
        ),
        if (hasSearch) ...[
          const SizedBox(height: 6),
          Text('Thử tìm theo SĐT, tên hoặc mã đơn',
              style: TextStyle(fontSize: 13, color: c.textTertiary)),
        ],
      ]),
    );
  }
}
