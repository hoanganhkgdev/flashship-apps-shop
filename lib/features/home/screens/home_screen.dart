import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/grab_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notification/models/notification_item.dart';
import '../../notification/providers/notification_provider.dart';
import '../../order/models/order_model.dart';
import '../../order/providers/order_provider.dart';
import '../../order/screens/order_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../stats/stats_screen.dart';
import '../providers/today_stats_provider.dart';
import '../../voucher/voucher_model.dart';
import '../../voucher/voucher_provider.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderListProvider.notifier).fetch();
      NotificationService.init();
    });

    NotificationService.onIncomingNotification = ({
      required title,
      required body,
      orderCode,
    }) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).add(NotificationItem(
        id:        DateTime.now().millisecondsSinceEpoch.toString(),
        title:     title,
        body:      body,
        orderCode: orderCode,
        createdAt: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty)
                Text(body, style: const TextStyle(fontSize: 13)),
            ]),
        action: orderCode != null
            ? SnackBarAction(label: 'Xem',
                onPressed: () => context.push('/order/$orderCode'))
            : null,
        duration: const Duration(seconds: 5),
      ));
      ref.read(orderListProvider.notifier).fetch(refresh: true);
    };
    NotificationService.onOrderTap = (code) {
      if (mounted) context.push('/order/$code');
    };
  }

  @override
  void dispose() {
    NotificationService.onIncomingNotification = null;
    super.dispose();
  }

  static const _tabs = [
    GrabNavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,         label: 'Trang chủ'),
    GrabNavItem(icon: Icons.list_alt_outlined,     activeIcon: Icons.list_alt_rounded,     label: 'Đơn hàng'),
    GrabNavItem(icon: Icons.bar_chart_outlined,    activeIcon: Icons.bar_chart_rounded,    label: 'Thống kê'),
    GrabNavItem(icon: Icons.storefront_outlined,   activeIcon: Icons.storefront_rounded,   label: 'Cửa hàng'),
  ];

  static const _pages = [_DashboardTab(), OrderListScreen(), StatsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_tabProvider);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: GrabBottomNav(
        selectedIndex: tab,
        items: _tabs,
        onTap: (i) => ref.read(_tabProvider.notifier).state = i,
      ),
    );
  }
}

// ─── Dashboard Tab ───────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authProvider).user;
    final orders      = ref.watch(orderListProvider);
    final active      = orders.active;
    final todayAsync  = ref.watch(todayStatsProvider);
    final c           = context.colors;

    // Số đang chạy THẬT lấy từ server (không giới hạn theo trang đã tải) —
    // active.length chỉ đếm được trong số đơn đã load về máy, thiếu nếu còn
    // đơn active nằm ở trang chưa tải. Cùng nguồn với badge trên header.
    final trueActiveCount = todayAsync.valueOrNull?.active ?? active.length;

    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: () async {
          ref.read(orderListProvider.notifier).fetch(refresh: true);
          ref.invalidate(todayStatsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── Header ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                shopName:    user?.name ?? 'Cửa hàng',
                shopAddress: user?.address ?? user?.phone ?? '',
                today:       todayAsync.valueOrNull,
              ),
            ),

            // ── Service cards ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.apps_rounded,
                        size: 15, color: context.colors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('Dịch vụ',
                      style: TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(children: [
                  Expanded(child: _ServiceCard(
                    icon: Icons.arrow_outward_rounded,
                    title: 'Giao đơn', sub: 'Shop → Khách',
                    color: c.primary,
                    onTap: () => context.push('/create-order', extra: true),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ServiceCard(
                    icon: Icons.move_to_inbox_rounded,
                    title: 'Lấy hộ', sub: 'Ngoài → Shop',
                    color: c.info,
                    onTap: () => context.push('/create-order', extra: false),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ServiceCard(
                    icon: Icons.route_rounded,
                    title: 'Đơn gộp', sub: 'Nhiều điểm giao',
                    color: c.success,
                    onTap: () => context.push('/create-batch'),
                  )),
                ]),
              ),
            ),

            // ── Voucher section ──────────────────────────────────────────
            const SliverToBoxAdapter(child: _VoucherSection()),

            // ── Active orders ────────────────────────────────────────────
            if (trueActiveCount > 0) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(children: [
                    Text('Đang chạy ($trueActiveCount)',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: c.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ...active.take(5).toList().asMap().entries.map((e) {
                        final i = e.key;
                        return Column(children: [
                          _OrderCard(order: e.value),
                          if (i < active.take(5).length - 1)
                            Divider(height: 1, indent: 60, color: c.divider),
                        ]);
                      }),
                      if (trueActiveCount > 5) ...[
                        Divider(height: 1, color: c.divider),
                        InkWell(
                          onTap: () =>
                              ref.read(_tabProvider.notifier).state = 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Xem tất cả $trueActiveCount đơn đang chạy',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.primary),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: c.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(child: _EmptyOrders()),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String      shopName;
  final String      shopAddress;
  final TodayStats? today;

  const _Header({
    required this.shopName,
    required this.shopAddress,
    this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final c      = context.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primary, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Tên shop + bell ────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Xin chào,',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(shopName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (shopAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 2),
                      Flexible(child: Text(shopAddress,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75)))),
                    ]),
                  ],
                ]),
              ),
              // ── Bell icon với badge ──────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/notifications'),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 22),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                ]),
              ),
            ]),

            // ── Stats hôm nay ──────────────────────────────────────────
            if (today != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _TodayStat(label: 'Đơn hôm nay', value: '${today!.orders}'),
                  _divider(),
                  _TodayStat(label: 'Đang chạy',   value: '${today!.active}'),
                  _divider(),
                  _TodayStat(
                    label: 'Doanh thu',
                    value: today!.revenue >= 1000
                        ? '${(today!.revenue / 1000).toStringAsFixed(0)}K'
                        : '${today!.revenue}đ',
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 28,
      color: Colors.white.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _TodayStat extends StatelessWidget {
  final String label, value;
  const _TodayStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
    ]),
  );
}

// ─── Service Card ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon, required this.title, required this.sub,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: c.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 16),
          ]),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, color: c.textSecondary)),
        ]),
      ),
    );
  }
}

// ─── Order Card (Grab style = customer pattern) ───────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  static const _cargoLabels = {
    'food':    (Icons.lunch_dining_rounded,   'Đồ ăn'),
    'flowers': (Icons.local_florist_rounded,  'Hoa / Trái cây'),
    'parcel':  (Icons.inventory_2_rounded,    'Bưu kiện'),
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
    final cargo       = _cargoLabels[order.cargoType]
        ?? (Icons.inventory_2_rounded, 'Bưu kiện');
    final statusColor = _statusColor(c);

    return InkWell(
      onTap: () => context.push('/order/${order.code}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Điểm nhấn trạng thái ─────────────────────────────────────
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),

          // ── Info ────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(cargo.$2,
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                  ),
                  Text(Fmt.currency(order.shippingFee),
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                ]),
                const SizedBox(height: 3),
                Text(order.deliveryAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 6),
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
                            fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                  const Spacer(),
                  Text(Fmt.timeAgo(order.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: c.textSecondary)),
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

// ─── Voucher Section ─────────────────────────────────────────────────────────

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voucherProvider);
    final c     = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (vouchers) {
        if (vouchers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_offer_rounded,
                      size: 15, color: c.success),
                ),
                const SizedBox(width: 8),
                Text('Mã giảm giá',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: c.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${vouchers.length}',
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: vouchers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _VoucherCard(voucher: vouchers[i]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  const _VoucherCard({required this.voucher});

  String get _discountText => voucher.type == 'percent'
      ? '-${voucher.value}%'
      : '-${voucher.value}đ';

  String get _expiry {
    if (voucher.expiresAt == null) return '';
    final d = voucher.expiresAt!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final expired = voucher.isExpired || voucher.isFull;
    final accent  = expired ? c.textTertiary : c.success;

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: voucher.code));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã sao chép: ${voucher.code}'),
          duration: const Duration(seconds: 2),
          backgroundColor: c.success,
        ));
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: c.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Left accent strip ──
          Container(
            width: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: expired
                    ? [c.surfaceAlt, c.surfaceAlt]
                    : [c.success, c.success.withValues(alpha: 0.75)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_discountText,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: expired ? c.textTertiary : Colors.white,
                        height: 1)),
                const SizedBox(height: 2),
                Text('OFF',
                    style: TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: expired
                            ? c.textTertiary
                            : Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),

          // ── Right content ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Code
                  Row(children: [
                    Text(voucher.code,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: accent, letterSpacing: 0.5)),
                    const SizedBox(width: 5),
                    Icon(Icons.copy_rounded, size: 12, color: accent),
                  ]),
                  const SizedBox(height: 4),
                  // Mô tả hoặc min order
                  Text(
                    voucher.description?.isNotEmpty == true
                        ? voucher.description!
                        : voucher.minOrderValue != null
                            ? 'Đơn từ ${voucher.minOrderValue}đ'
                            : 'Không giới hạn đơn tối thiểu',
                    style: TextStyle(fontSize: 10, color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // HSD + usage
                  Row(children: [
                    if (voucher.expiresAt != null) ...[
                      Icon(Icons.access_time_rounded,
                          size: 10,
                          color: expired ? c.danger : c.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        expired ? 'Hết hạn' : _expiry,
                        style: TextStyle(
                            fontSize: 10,
                            color: expired ? c.danger : c.textTertiary),
                      ),
                    ],
                    if (voucher.usageLimit != null) ...[
                      const Spacer(),
                      Text(
                        '${voucher.usageCount ?? 0}/${voucher.usageLimit}',
                        style: TextStyle(
                            fontSize: 10,
                            color: c.textTertiary),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: c.cardShadow),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined, size: 48,
              color: c.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('Chưa có đơn nào đang chạy',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Chọn dịch vụ bên trên để tạo đơn mới',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
