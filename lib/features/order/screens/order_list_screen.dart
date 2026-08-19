import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/cargo_type.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

final _filterProvider      = StateProvider<String>((ref) => 'all');
final _searchQueryProvider = StateProvider<String>((ref) => '');

bool _matchesSearch(OrderModel o, String query) {
  if (query.isEmpty) return true;
  if (o.code.toLowerCase().contains(query)) return true;
  if (o.deliveryPhone.toLowerCase().contains(query)) return true;
  if (o.receiverName?.toLowerCase().contains(query) == true) return true;
  return false;
}

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
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Backend trả 20 đơn/trang — không có cuộn vô hạn thì shop có trên 20
    // đơn sẽ không bao giờ thấy được đơn cũ hơn (không có ô tìm kiếm nào
    // khác để tra lại). Tải thêm khi cuộn gần cuối danh sách.
    // Tìm kiếm chỉ lọc trên dữ liệu đã tải nên vẫn tải thêm bình thường khi
    // đang có searchQuery — càng tải nhiều càng tìm được nhiều.
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

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(orderListProvider);
    final filter = ref.watch(_filterProvider);
    final query  = ref.watch(_searchQueryProvider).trim().toLowerCase();
    final all    = state.orders;
    final c      = context.colors;

    final displayed = switch (filter) {
      'active'    => all.where((o) => _activeStatuses.contains(o.status)).toList(),
      'completed' => all.where((o) => o.isCompleted).toList(),
      'cancelled' => all.where((o) => o.isCancelled).toList(),
      _           => all,
    }.where((o) => _matchesSearch(o, query)).toList();

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

                // Thanh tìm kiếm
                AppField(
                  controller: _searchCtrl,
                  hint: 'Tìm mã đơn, SĐT người nhận...',
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                  onChanged: (v) =>
                      ref.read(_searchQueryProvider.notifier).state = v,
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
                            child: Center(
                              child: Text('${f.$2} $count',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? c.primary
                                          : c.textSecondary)),
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
                    ? _EmptyState(filter: filter, searching: query.isNotEmpty)
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
                              return _OrderCard(
                                  key: ValueKey(displayed[idx].code),
                                  order: displayed[idx]);
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.divider),
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
  const _OrderCard({super.key, required this.order});

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

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // Giả lập hiệu ứng "mờ 50%" bằng cách giảm alpha màu trực tiếp thay vì bọc
  // Opacity — Opacity đổi giữa 1.0/<1.0 khi nhiều item trong ListView bị dựng
  // lại đồng loạt (vd đổi tab lọc) có thể gây lỗi framework Flutter
  // ("!semantics.parentDataDirty", có lúc lộ ra thành lỗi khác ở frame sau).
  // Giảm alpha ở bước paint không tạo compositing layer nào nên tránh hẳn lớp
  // bug này. Nền card luôn là c.surface nên kết quả thị giác gần như tương
  // đương Opacity(0.5).
  Color _fade(Color color) =>
      order.isCancelled ? color.withValues(alpha: color.a * 0.5) : color;

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final accent  = _accentColor(c);
    final address = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm · ${order.stops.first['address'] ?? ''}'
        : order.deliveryAddress;
    final cargoMeta = cargoTypeOf(order.cargoType);
    final cargo   = (cargoMeta.label, cargoMeta.color);
    final service = _serviceMeta[order.shopServiceType]
        ?? ('Giao đến', const Color(0xFF3B82F6));
    final dimmed  = order.isCancelled;

    final receiver = [
      if (order.receiverName?.isNotEmpty == true) order.receiverName!,
      order.deliveryPhone,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.divider),
          ),
          clipBehavior: Clip.antiAlias,
          // IntrinsicHeight: Row(crossAxisAlignment: stretch) cần chiều cao
          // xác định để giãn các con — nhưng item trong ListView vốn cho
          // chiều cao vô hạn (tự co theo nội dung), gây lỗi layout
          // "BoxConstraints forces an infinite height" nếu không có dòng này.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Dải accent trạng thái — không bị làm mờ ─────────────
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: status badge · fee
                        Row(children: [
                          StatusBadge(
                              label: Fmt.orderStatus(order.status),
                              color: _fade(accent)),
                          const Spacer(),
                          Text(Fmt.currency(order.shippingFee),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _fade(
                                      dimmed ? c.textTertiary : c.primary),
                                  decoration: dimmed
                                      ? TextDecoration.lineThrough
                                      : null)),
                        ]),
                        const SizedBox(height: 10),

                        // Row 2: receiver + phone
                        Row(children: [
                          Icon(Icons.person_outline_rounded,
                              size: 14, color: _fade(c.textTertiary)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(receiver,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _fade(dimmed
                                        ? c.textTertiary
                                        : c.textPrimary))),
                          ),
                          if (order.deliveryPhone.isNotEmpty &&
                              !order.isCancelled) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _call(order.deliveryPhone),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.call_rounded,
                                    size: 12, color: c.primary),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 5),

                        // Row 3: address
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: _fade(c.textTertiary)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(address,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _fade(c.textSecondary))),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        Divider(height: 1, color: _fade(c.divider)),
                        const SizedBox(height: 10),

                        // Row 4: chips + time
                        Row(children: [
                          _Chip(
                              label: service.$1,
                              color: service.$2,
                              dimmed: dimmed),
                          const SizedBox(width: 6),
                          _Chip(
                              label: cargo.$1, color: cargo.$2, dimmed: dimmed),
                          if (order.isBatch) ...[
                            const SizedBox(width: 6),
                            _Chip(label: '${order.stops.length} điểm',
                                color: c.success, dimmed: dimmed),
                          ],
                          const Spacer(),
                          Icon(Icons.access_time_rounded,
                              size: 12, color: _fade(c.textTertiary)),
                          const SizedBox(width: 3),
                          Text(Fmt.timeAgo(order.createdAt),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _fade(c.textSecondary))),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
  final bool   searching;
  const _EmptyState({required this.filter, this.searching = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: searching
            ? 'Không tìm thấy đơn phù hợp'
            : filter == 'active'
                ? 'Không có đơn đang chạy'
                : filter == 'all'
                    ? 'Chưa có đơn hàng nào'
                    : 'Không có đơn phù hợp',
      ),
    );
  }
}
