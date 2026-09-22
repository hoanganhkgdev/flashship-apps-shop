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
    ('processing', 'Đang xử lý'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(_searchQueryProvider);
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
      'pending' => all.where((o) => o.status == 'pending').toList(),
      'processing' => all
          .where((o) => const ['assigned', 'processing'].contains(o.status))
          .toList(),
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
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 18, 20, 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Đơn hàng',
                      style: TextStyle(
                          fontSize: AppFontSize.xxxl,
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
                ]),
                const SizedBox(height: 14),
                AppField(
                  controller: _searchCtrl,
                  hint: 'Tìm mã đơn, tên hoặc SĐT người nhận',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: c.textTertiary),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(_searchQueryProvider.notifier).state = '';
                          },
                        ),
                  onChanged: (v) =>
                      ref.read(_searchQueryProvider.notifier).state = v,
                ),
              ],
            ),
          ),

          // Filter chips — pill rời, cuộn ngang.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: SizedBox(
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
                        border: selected ? null : Border.all(color: c.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(f.$2,
                          style: TextStyle(
                              fontSize: AppFontSize.base,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              color:
                                  selected ? Colors.white : c.textSecondary)),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: c.primary,
              onRefresh: () =>
                  ref.read(orderListProvider.notifier).fetch(refresh: true),
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (displayed.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (state.isLoading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(state.error!,
                                  textAlign: TextAlign.center),
                            )
                          else
                            _EmptyState(
                                filter: filter, searching: query.isNotEmpty),
                          if (!state.isLoading &&
                              (query.isNotEmpty || filter != 'all'))
                            TextButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(_searchQueryProvider.notifier).state =
                                    '';
                                ref.read(_filterProvider.notifier).state =
                                    'all';
                              },
                              child: const Text('Xóa tìm kiếm và bộ lọc'),
                            ),
                          if (!state.isLoading &&
                              (state.hasMore || state.error != null))
                            _buildLoadMore(state),
                        ],
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: displayed.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _OrderCard(
                          key: ValueKey(displayed[i].code),
                          order: displayed[i],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildLoadMore(state)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMore(OrderListState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          if (state.isLoading)
            const CircularProgressIndicator(strokeWidth: 2)
          else ...[
            if (state.error != null && state.orders.isNotEmpty)
              Text(state.error!, textAlign: TextAlign.center),
            if (state.hasMore || state.error != null) ...[
              const Text(
                'Tìm kiếm và bộ lọc áp dụng cho các đơn đã tải.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.read(orderListProvider.notifier).fetch(),
                icon: Icon(state.error != null
                    ? Icons.refresh_rounded
                    : Icons.expand_more_rounded),
                label:
                    Text(state.error != null ? 'Thử lại' : 'Tải thêm đơn hàng'),
              ),
            ],
          ],
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
        ('processing', 'Đã lấy', c.success),
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
                          fontSize: AppFontSize.xxl,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: AppFontSize.xs,
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
          border: Border.all(color: c.divider),
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
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.w700,
                            color: _fade(
                                dimmed ? c.textTertiary : c.textPrimary))),
                    const SizedBox(width: 6),
                    Text('· $time',
                        style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: _fade(c.textTertiary))),
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
                  child: Text(
                      order.status == 'processing'
                          ? 'Đã lấy hàng'
                          : Fmt.orderStatus(order.status),
                      style: TextStyle(
                          fontSize: AppFontSize.sm,
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
                          fontSize: AppFontSize.base,
                          color: _fade(c.textSecondary))),
                ),
              ]),
              const SizedBox(height: 12),

              Divider(height: 1, color: _fade(c.divider)),
              const SizedBox(height: 10),

              // Row 3: COD · loại hàng ............................... phí
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text(
                    dimmed
                        ? 'Khách huỷ đơn'
                        : 'COD ${Fmt.currency(order.codAmount ?? 0)} · ${cargoMeta.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w500,
                        color: _fade(c.textTertiary)),
                  ),
                ),
                Text(Fmt.currency(order.shippingFee),
                    style: TextStyle(
                        fontSize: AppFontSize.xl,
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
                : filter == 'processing'
                    ? 'Không có đơn đang xử lý'
                    : filter == 'all'
                        ? 'Chưa có đơn hàng nào'
                        : 'Không có đơn phù hợp',
      ),
    );
  }
}
