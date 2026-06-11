import 'package:flutter/material.dart';
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
      backgroundColor: AppColors.background,
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

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.primary,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  Expanded(child: _ServiceCard(
                    icon: Icons.arrow_outward_rounded,
                    title: 'Giao đơn', sub: 'Shop → Khách',
                    color: AppColors.primary,
                    onTap: () => context.push('/create-order', extra: true),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ServiceCard(
                    icon: Icons.move_to_inbox_rounded,
                    title: 'Lấy hộ', sub: 'Ngoài → Shop',
                    color: AppColors.info,
                    onTap: () => context.push('/create-order', extra: false),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ServiceCard(
                    icon: Icons.route_rounded,
                    title: 'Đơn gộp', sub: 'Nhiều điểm giao',
                    color: AppColors.success,
                    onTap: () => context.push('/create-batch'),
                  )),
                ]),
              ),
            ),

            // ── Active orders ────────────────────────────────────────────
            if (active.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(children: [
                    Text('Đang chạy (${active.length})',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ...active.take(5).toList().asMap().entries.map((e) {
                        final i = e.key;
                        return Column(children: [
                          _OrderCard(order: e.value),
                          if (i < active.take(5).length - 1)
                            const Divider(height: 1, indent: 60,
                                color: Color(0xFFF5F5F5)),
                        ]);
                      }),
                      if (active.length > 5) ...[
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        InkWell(
                          onTap: () =>
                              ref.read(_tabProvider.notifier).state = 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Xem tất cả ${active.length} đơn đang chạy',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: AppColors.primary),
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

// ─── Header (flat) ────────────────────────────────────────────────────────────

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

    return Container(
      color: AppColors.primary,
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
                          color: AppColors.danger,
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

// ─── Order Card (Grab style = customer pattern) ───────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  static const _cargoLabels = {
    'food':    (Icons.lunch_dining_rounded,   'Đồ ăn',          Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded,  'Hoa / Trái cây', Color(0xFFEC4899)),
    'parcel':  (Icons.inventory_2_rounded,    'Bưu kiện',       Color(0xFF6B7280)),
  };

  Color _statusColor() {
    if (order.isCompleted) return AppColors.success;
    if (order.isCancelled) return AppColors.danger;
    if (order.status == 'pending') return const Color(0xFFF59E0B);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cargo       = _cargoLabels[order.cargoType]
        ?? (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));
    final statusColor = _statusColor();

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
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Text(Fmt.currency(order.shippingFee),
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 3),
                Text(order.deliveryAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
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
                            fontWeight: FontWeight.w600, color: statusColor)),
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(Icons.inventory_2_outlined, size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            const Text('Chưa có đơn nào đang chạy',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('Chọn dịch vụ bên trên để tạo đơn mới',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}
