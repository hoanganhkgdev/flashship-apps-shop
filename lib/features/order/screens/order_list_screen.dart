import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/cargo_type.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

final _filterProvider = StateProvider<String>((ref) => 'all');
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
    ('all', 'Tất cả'),
    ('pending', 'Chờ xử lý'),
    ('delivering', 'Đang giao'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _searchExpanded = false;

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
    final state = ref.watch(orderListProvider);
    final filter = ref.watch(_filterProvider);
    final query = ref.watch(_searchQueryProvider).trim().toLowerCase();
    final all = state.orders;
    final c = context.colors;

    final displayed = switch (filter) {
      'pending' => all
          .where((o) =>
              const ['pending', 'assigned', 'processing'].contains(o.status))
          .toList(),
      'delivering' => all.where((o) => o.status == 'on_the_way').toList(),
      'completed' => all.where((o) => o.isCompleted).toList(),
      'cancelled' => all.where((o) => o.isCancelled).toList(),
      _ => all,
    }
        .where((o) => _matchesSearch(o, query))
        .toList();

    return ColoredBox(
      color: c.background,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: c.background,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Đơn hàng',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                  const Spacer(),
                  if (state.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.primary)),
                    ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchExpanded = !_searchExpanded;
                      if (!_searchExpanded) {
                        _searchCtrl.clear();
                        ref.read(_searchQueryProvider.notifier).state = '';
                      }
                    }),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: c.cardShadow,
                      ),
                      child: Icon(
                        _searchExpanded
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        size: 21,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Thanh tìm kiếm
                if (_searchExpanded) ...[
                  AppField(
                    controller: _searchCtrl,
                    hint: 'Tìm mã đơn, SĐT người nhận...',
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: c.textTertiary),
                    onChanged: (v) =>
                        ref.read(_searchQueryProvider.notifier).state = v,
                  ),
                  const SizedBox(height: 12),
                ],

                // Filter chips — pill rời, cuộn ngang, chip đang chọn tô đặc
                // màu primary thay vì khối nền xám bọc chung như trước.
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final selected = filter == f.$1;
                      return GestureDetector(
                        onTap: () =>
                            ref.read(_filterProvider.notifier).state = f.$1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: selected ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border:
                                selected ? null : Border.all(color: c.divider),
                          ),
                          alignment: Alignment.center,
                          child: Text(f.$2,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : c.textSecondary)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 13),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && all.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                        color: c.primary, strokeWidth: 2))
                : displayed.isEmpty
                    ? _EmptyState(filter: filter, searching: query.isNotEmpty)
                    : RefreshIndicator(
                        color: c.primary,
                        onRefresh: () => ref
                            .read(orderListProvider.notifier)
                            .fetch(refresh: true),
                        child: Builder(builder: (_) {
                          // Chỉ hiện khi "Tất cả" — các tab khác lọc phía app
                          // nên tổng số trang backend không khớp số dòng hiện ra.
                          final showFooter = filter == 'all' &&
                              state.hasMore &&
                              state.isLoading &&
                              all.isNotEmpty;
                          return ListView.separated(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                            itemCount: displayed.length + (showFooter ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final idx = i;
                              if (idx >= displayed.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
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

// Giữ lại component tổng quan để có thể tái sử dụng ở dashboard vận hành.
// ignore: unused_element
class _ActiveSummary extends StatelessWidget {
  final List<OrderModel> orders;
  const _ActiveSummary({required this.orders});

  static List<(String, String, Color)> _steps(Palette c) => [
        ('pending', 'Chờ tài xế', c.warning),
        ('assigned', 'Đã nhận', c.primary),
        ('processing', 'Đang lấy', const Color(0xFF8B5CF6)),
        ('on_the_way', 'Đang giao', c.success),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final steps = _steps(c);
    final counts = {
      for (final (s, _, _) in steps)
        s: orders.where((o) => o.status == s).length
    };
    final nonZero = steps.where((s) => (counts[s.$1] ?? 0) > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
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

  Color _accentColor(Palette c) {
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    if (order.status == 'processing') return const Color(0xFF8B5CF6);
    return c.primary;
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
    final c = context.colors;
    final accent = _accentColor(c);
    final address = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm · ${order.stops.first['address'] ?? ''}'
        : order.deliveryAddress;
    final cargoMeta = cargoTypeOf(order.cargoType);
    final dimmed = order.isCancelled;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final local = order.createdAt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    final time = isToday
        ? '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'
        : isYesterday
            ? 'hôm qua'
            : Fmt.timeAgo(local);

    // Badge trạng thái dạng pill (nền nhạt + chữ đậm màu) thay cho chấm tròn
    // + chữ — đồng bộ mockup thiết kế mới.
    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: c.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: mã đơn + giờ ............. badge trạng thái
              Row(children: [
                Expanded(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(code,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _fade(
                                dimmed ? c.textTertiary : c.textPrimary))),
                    const SizedBox(width: 6),
                    Text('· $time',
                        style: TextStyle(
                            fontSize: 12, color: _fade(c.textTertiary))),
                  ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: _fade(accent)
                        .withValues(alpha: context.isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(Fmt.orderStatus(order.status),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _fade(accent))),
                ),
              ]),
              const SizedBox(height: 10),

              // Row 2: địa chỉ giao
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: _fade(c.textTertiary)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: _fade(c.textSecondary))),
                ),
              ]),
              const SizedBox(height: 12),

              Divider(height: 1, color: _fade(c.divider)),
              const SizedBox(height: 10),

              // Row 3: COD · loại hàng ............................... phí
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text(
                    'COD ${Fmt.currency(order.codAmount ?? 0)} · ${cargoMeta.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _fade(c.textTertiary)),
                  ),
                ),
                Text(Fmt.currency(order.shippingFee),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _fade(dimmed ? c.textTertiary : c.primary),
                        decoration:
                            dimmed ? TextDecoration.lineThrough : null)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  final bool searching;
  const _EmptyState({required this.filter, this.searching = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: searching
            ? 'Không tìm thấy đơn phù hợp'
            : filter == 'pending'
                ? 'Không có đơn chờ xử lý'
                : filter == 'delivering'
                    ? 'Không có đơn đang giao'
                    : filter == 'all'
                        ? 'Chưa có đơn hàng nào'
                        : 'Không có đơn phù hợp',
      ),
    );
  }
}
