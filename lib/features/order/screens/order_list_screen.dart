import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

final _filterProvider = StateProvider<String>((ref) => 'all');

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  static const _filters = [
    ('all',       'Tất cả'),
    ('active',    'Đang chạy'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  static const _activeStatuses = ['pending', 'assigned', 'processing', 'on_the_way'];

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Backend trả 20 đơn/trang — không có cuộn vô hạn thì shop có trên 20
    // đơn sẽ không bao giờ thấy được đơn cũ hơn (không có ô tìm kiếm nào
    // khác để tra lại). Tải thêm khi cuộn gần cuối danh sách.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(orderListProvider);
    final filter = ref.watch(_filterProvider);
    final all    = state.orders;
    final c      = context.colors;

    final displayed = switch (filter) {
      'active'    => all.where((o) => _activeStatuses.contains(o.status)).toList(),
      'completed' => all.where((o) => o.isCompleted).toList(),
      'cancelled' => all.where((o) => o.isCancelled).toList(),
      _           => all,
    };

    final counts = {
      'all':       all.length,
      'active':    all.where((o) => _activeStatuses.contains(o.status)).length,
      'completed': all.where((o) => o.isCompleted).length,
      'cancelled': all.where((o) => o.isCancelled).length,
    };

    return ColoredBox(
      color: c.background,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: c.surface,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Text('Đơn hàng',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const Spacer(),
                    if (state.isLoading)
                      SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.primary)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Segmented filter tabs
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: _filters.map((f) {
                      final selected = filter == f.$1;
                      final count   = counts[f.$1] ?? 0;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              ref.read(_filterProvider.notifier).state = f.$1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: selected ? c.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: selected
                                  ? [BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1))]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(f.$2,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? c.primary
                                            : c.textSecondary)),
                                const SizedBox(height: 1),
                                Text('$count',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? c.primary
                                            : c.textTertiary)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 1),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && all.isEmpty
                ? Center(child: CircularProgressIndicator(
                    color: c.primary, strokeWidth: 2))
                : displayed.isEmpty
                    ? _EmptyState(filter: filter)
                    : RefreshIndicator(
                        color: c.primary,
                        onRefresh: () => ref
                            .read(orderListProvider.notifier)
                            .fetch(refresh: true),
                        child: Builder(builder: (_) {
                          final showSummary = filter == 'active' && displayed.isNotEmpty;
                          // Chỉ hiện khi "Tất cả" — các tab khác lọc phía app
                          // nên tổng số trang backend không khớp số dòng hiện ra.
                          final showFooter = filter == 'all' &&
                              state.hasMore && state.isLoading && all.isNotEmpty;
                          final extraTop = showSummary ? 1 : 0;

                          return ListView.separated(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                            itemCount: displayed.length + extraTop + (showFooter ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              if (showSummary && i == 0) {
                                return _ActiveSummary(orders: displayed);
                              }
                              final idx = i - extraTop;
                              if (idx >= displayed.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: c.primary),
                                    ),
                                  ),
                                );
                              }
                              return _OrderCard(order: displayed[idx]);
                            },
                          );
                        }),
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
    final c      = context.colors;
    final steps  = _steps(c);
    final counts = {for (final (s, _, _) in steps)
      s: orders.where((o) => o.status == s).length
    };
    final nonZero = steps.where((s) => (counts[s.$1] ?? 0) > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        children: nonZero.map((item) {
          final (key, label, color) = item;
          final count = counts[key] ?? 0;
          return Expanded(
            child: Column(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.w800, color: color)),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(fontSize: 11,
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
    'food':    ('Đồ ăn',          Color(0xFFF59E0B)),
    'flowers': ('Hoa / Trái cây', Color(0xFFEC4899)),
    'parcel':  ('Bưu kiện',       Color(0xFF6B7280)),
  };

  static const _serviceMeta = {
    'shop_delivery': ('Giao đến',   Color(0xFF3B82F6)),
    'shop_pickup':   ('Nhận về',    Color(0xFF8B5CF6)),
    'shop_batch':    ('Giao nhiều', Color(0xFF10B981)),
  };

  Color _accentColor(Palette c) {
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    if (order.status == 'processing') return const Color(0xFF8B5CF6);
    return c.primary;
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final accent  = _accentColor(c);
    final isDark  = context.isDark;
    final address = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm · ${order.stops.first['address'] ?? ''}'
        : order.deliveryAddress;
    final cargo   = _cargoMeta[order.cargoType]
        ?? ('Bưu kiện', const Color(0xFF6B7280));
    final service = _serviceMeta[order.shopServiceType]
        ?? ('Giao đến', const Color(0xFF3B82F6));
    final dimmed  = order.isCancelled;

    final receiver = [
      if (order.receiverName?.isNotEmpty == true) order.receiverName!,
      order.deliveryPhone,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: order.isCancelled
                ? c.danger.withValues(alpha: isDark ? 0.07 : 0.04)
                : order.isCompleted
                    ? c.success.withValues(alpha: isDark ? 0.07 : 0.04)
                    : c.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: c.cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: status dot + label · fee
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(Fmt.orderStatus(order.status),
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700, color: accent)),
                  ]),
                ),
                const Spacer(),
                Text(Fmt.currency(order.shippingFee),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dimmed ? c.textTertiary : c.primary,
                        decoration: dimmed ? TextDecoration.lineThrough : null)),
              ]),
              const SizedBox(height: 10),

              // Row 2: receiver + phone
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: c.textTertiary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(receiver,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dimmed ? c.textTertiary : c.textPrimary)),
                ),
              ]),
              const SizedBox(height: 5),

              // Row 3: address
              Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: c.textTertiary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(address,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
              ]),
              const SizedBox(height: 10),

              Divider(height: 1, color: c.divider),
              const SizedBox(height: 10),

              // Row 4: chips + time
              Row(children: [
                _Chip(label: service.$1, color: service.$2, dimmed: dimmed),
                const SizedBox(width: 6),
                _Chip(label: cargo.$1, color: cargo.$2, dimmed: dimmed),
                if (order.isBatch) ...[
                  const SizedBox(width: 6),
                  _Chip(label: '${order.stops.length} điểm',
                      color: c.success, dimmed: dimmed),
                ],
                const Spacer(),
                Icon(Icons.access_time_rounded, size: 12, color: c.textTertiary),
                const SizedBox(width: 3),
                Text(Fmt.timeAgo(order.createdAt),
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   dimmed;
  const _Chip({required this.label, required this.color, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = dimmed ? context.colors.textTertiary : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: context.isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: effectiveColor)),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

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
          child: Icon(Icons.receipt_long_outlined, size: 34, color: c.textTertiary),
        ),
        const SizedBox(height: 14),
        Text(
          filter == 'active'
              ? 'Không có đơn đang chạy'
              : filter == 'all'
                  ? 'Chưa có đơn hàng nào'
                  : 'Không có đơn phù hợp',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: c.textSecondary),
        ),
      ]),
    );
  }
}
