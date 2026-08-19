import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/store_launcher.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/stat_row.dart';
import '../../address/models/address_entry.dart';
import '../../address/providers/address_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notification/models/notification_item.dart';
import '../../notification/providers/notification_provider.dart';
import '../../order/models/cargo_type.dart';
import '../../order/models/order_model.dart';
import '../../order/providers/order_provider.dart';
import '../../order/screens/order_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../stats/stats_screen.dart';
import '../providers/today_stats_provider.dart';
import '../../version/providers/app_version_provider.dart';
import '../../voucher/voucher_provider.dart';
import '../../voucher/widgets/voucher_card.dart';

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
      if (!mounted) return;
      // GoRouter.of(context).state phản ánh route đang active trên toàn app
      // (không phụ thuộc context của home_screen) — nếu người dùng đang xem
      // đúng đơn này rồi thì bỏ qua, OrderDetailScreen đã tự cập nhật qua
      // RTDB/FCM listener sẵn có, không cần điều hướng chồng thêm 1 lớp nữa.
      final currentLocation = GoRouter.of(context).state.uri.toString();
      if (currentLocation == '/order/$code') return;
      context.push('/order/$code');
    };
    // Firebase xoay vòng FCM token định kỳ — đăng ký lại với backend ngay khi
    // đổi, tránh trường hợp backend giữ token cũ đã hết hiệu lực.
    NotificationService.onTokenRefresh = (newToken) {
      ref.read(authProvider.notifier).updateFcmToken(newToken);
    };
  }

  @override
  void dispose() {
    NotificationService.onIncomingNotification = null;
    NotificationService.onOrderTap = null;
    NotificationService.onTokenRefresh = null;
    super.dispose();
  }

  static const _tabs = [
    AppNavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,         label: 'Trang chủ'),
    AppNavItem(icon: Icons.list_alt_outlined,     activeIcon: Icons.list_alt_rounded,     label: 'Đơn hàng'),
    AppNavItem(icon: Icons.bar_chart_outlined,    activeIcon: Icons.bar_chart_rounded,    label: 'Thống kê'),
    AppNavItem(icon: Icons.storefront_outlined,   activeIcon: Icons.storefront_rounded,   label: 'Cửa hàng'),
  ];

  static const _pages = [_DashboardTab(), OrderListScreen(), StatsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_tabProvider);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: AppBottomNav(
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

            // ── Banner nhắc cập nhật (không bắt buộc) ─────────────────────
            const SliverToBoxAdapter(child: _SoftUpdateBanner()),

            // ── Dịch vụ — thẻ trắng shadow chứa các ô thao tác màu, đồng bộ
            // khối "Tài chính" của app driver ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: c.cardShadow,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dịch vụ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _ServiceTile(
                        icon:  Icons.local_shipping_outlined,
                        color: c.success,
                        label: 'Giao đơn',
                        onTap: () => context.push('/create-order', extra: true),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ServiceTile(
                        icon:  Icons.location_on_outlined,
                        color: c.info,
                        label: 'Lấy hộ',
                        onTap: () => context.push('/create-order', extra: false),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ServiceTile(
                        icon:  Icons.layers_outlined,
                        color: c.warning,
                        label: 'Đơn gộp',
                        onTap: () => context.push('/create-batch'),
                      )),
                    ]),
                  ]),
                ),
              ),
            ),

            // ── Active orders ────────────────────────────────────────────
            if (trueActiveCount > 0) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(children: [
                    Text('Đang chạy',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$trueActiveCount',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                ),
              ),
              // Mỗi đơn 1 thẻ trắng shadow riêng, cách nhau bằng khoảng trắng
              // — đồng bộ ActiveOrderCard/CompletedOrderCard app driver, thay
              // vì gộp chung 1 khối lớn ngăn bằng Divider như trước.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: active.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = active[i];
                    return _OrderCard(key: ValueKey(order.code), order: order);
                  },
                ),
              ),
              if (trueActiveCount > 5)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => ref.read(_tabProvider.notifier).state = 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  ),
                ),
            ] else ...[
              SliverToBoxAdapter(child: _EmptyOrders()),
            ],

            // ── Banner thông báo/khuyến mãi (không phải ưu tiên chính) ────
            const SliverToBoxAdapter(child: _HomeBannerSection()),

            // ── Địa chỉ thường dùng ───────────────────────────────────────
            const SliverToBoxAdapter(child: _FrequentAddressSection()),

            // ── Voucher section ──────────────────────────────────────────
            const SliverToBoxAdapter(child: _VoucherSection()),

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
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final c      = context.colors;
    final top    = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Hình tròn trang trí mờ — đồng bộ hero header app driver ──
          Positioned(
            top: -70, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -40, top: 110,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Tên shop + bell ────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Xin chào 👋',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text(shopName,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.4,
                            shadows: [
                              Shadow(color: Color(0x26000000),
                                  blurRadius: 4, offset: Offset(0, 1)),
                            ]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (shopAddress.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 3),
                        Flexible(child: Text(shopAddress,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.85)))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                // ── Bell icon với badge ──────────────────────────────────
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -2, right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800,
                                  color: c.primary)),
                        ),
                      ),
                  ]),
                ),
              ]),

              // ── Thống kê hôm nay — thẻ trắng nổi bằng shadow trên nền
              // gradient (giống card toggle của app driver) ───────────────
              if (today != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: StatRow(items: [
                    StatItem(value: '${today!.orders}', label: 'Đơn hôm nay'),
                    StatItem(
                      value: '${today!.active}',
                      label: 'Đang chạy',
                      valueColor: today!.active > 0 ? c.primary : null,
                    ),
                    StatItem(
                      value: today!.revenue >= 1000
                          ? '${(today!.revenue / 1000).toStringAsFixed(0)}K'
                          : '${today!.revenue}đ',
                      label: 'Doanh thu',
                      valueColor: today!.revenue > 0 ? c.success : null,
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Ô dịch vụ ────────────────────────────────────────────────────────────────
// Nền tint nhạt theo màu + viền cùng tông (alpha 0.07/0.18) — cùng pattern
// với ô "Ví cá nhân"/"Công nợ" trong FinanceCard của app driver.
class _ServiceTile extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final String        label;
  final VoidCallback  onTap;

  const _ServiceTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: color)),
          ]),
        ),
      );
}

// ─── Banner thông báo/khuyến mãi ───────────────────────────────────────────────
// TODO: đang hardcode _homeBanners tĩnh. Khi backend có endpoint thông báo hệ
// thống (vd GET /shop/announcements), thay bằng 1 provider fetch danh sách rồi
// truyền vào _HomeBannerSection — widget đã sẵn carousel cho trường hợp >1 banner.

class _BannerItem {
  final IconData icon;
  final String   title;
  final String   route;
  const _BannerItem({
    required this.icon,
    required this.title,
    required this.route,
  });
}

const _homeBanners = <_BannerItem>[
  _BannerItem(
    icon: Icons.campaign_rounded,
    title: 'Ưu đãi phí giao hàng tuần này — giảm đến 15% cho đơn nội thành',
    route: '/notifications',
  ),
];

// ─── Banner nhắc cập nhật mềm ───────────────────────────────────────────────
//
// Khác dialog "Cập nhật bắt buộc" (main.dart) — không chặn thao tác, có thể
// bấm "Để sau" để ẩn cho đúng phiên bản này (xem dismissedSoftUpdateVersionProvider).
class _SoftUpdateBanner extends ConsumerWidget {
  const _SoftUpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version           = ref.watch(appVersionProvider);
    final dismissedVersion  = ref.watch(dismissedSoftUpdateVersionProvider);

    final shouldShow = version.needsSoftUpdate &&
        version.latestVersion != null &&
        version.latestVersion != dismissedVersion;
    if (!shouldShow) return const SizedBox.shrink();

    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(Icons.system_update_rounded, color: c.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Đã có bản cập nhật mới',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              final v = version.latestVersion;
              if (v != null) {
                ref.read(dismissedSoftUpdateVersionProvider.notifier).dismiss(v);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Để sau',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => openStore(version.storeUrl),
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cập nhật',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _HomeBannerSection extends StatelessWidget {
  const _HomeBannerSection();

  @override
  Widget build(BuildContext context) {
    if (_homeBanners.isEmpty) return const SizedBox.shrink();

    if (_homeBanners.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _BannerCard(item: _homeBanners.first),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        itemCount: _homeBanners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          child: _BannerCard(item: _homeBanners[i]),
        ),
      ),
    );
  }
}

// Thu gọn thành 1 dòng mỏng — banner khuyến mãi không phải ưu tiên hàng đầu
// của công cụ vận hành, chỉ cần đủ nhận diện, không chiếm nhiều diện tích.
class _BannerCard extends StatelessWidget {
  final _BannerItem item;
  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push(item.route),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: c.cardShadow,
        ),
        child: Row(children: [
          Icon(item.icon, color: c.primary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 16),
        ]),
      ),
    );
  }
}

// ─── Địa chỉ thường dùng ────────────────────────────────────────────────────────

class _FrequentAddressSection extends ConsumerWidget {
  const _FrequentAddressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressProvider);
    final c     = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on_rounded, size: 15, color: c.info),
                ),
                const SizedBox(width: 8),
                Text('Địa chỉ thường dùng',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: c.textPrimary)),
              ]),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _AddressChip(entry: addresses[i]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _AddressChip extends StatelessWidget {
  final AddressEntry entry;
  const _AddressChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push('/create-order', extra: entry),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_rounded, size: 14, color: c.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(entry.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ),
        ]),
      ),
    );
  }
}

// ─── Order Card (Grab style = customer pattern) ───────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  // Hệ thống chỉ có 6 status thật (pending/assigned/processing/on_the_way/
  // completed/cancelled) — không có status riêng cho "giao thất bại" hay "huỷ
  // chờ xác nhận". Tín hiệu "cần chú ý" khả dụng duy nhất từ dữ liệu hiện có:
  // đơn còn 'pending' (chưa tìm được tài xế) quá lâu so với lúc tạo.
  static const _pendingAttentionThreshold = Duration(minutes: 15);

  bool get _needsAttention =>
      order.status == 'pending' &&
      DateTime.now().difference(order.createdAt) >= _pendingAttentionThreshold;

  Color _statusColor(Palette c) {
    if (_needsAttention) return c.danger;
    if (order.isCompleted) return c.success;
    if (order.isCancelled) return c.danger;
    if (order.status == 'pending') return c.warning;
    return c.primary;
  }

  @override
  Widget build(BuildContext context) {
    final c           = context.colors;
    final cargo       = cargoTypeOf(order.cargoType);
    final statusColor = _statusColor(c);
    final attention   = _needsAttention;

    // Thẻ trắng shadow riêng cho từng đơn — icon loại hàng + chấm trạng
    // thái, đồng bộ ActiveOrderCard của app driver.
    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: c.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Icon loại hàng ────────────────────────────────────────
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: cargo.color.withValues(
                      alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cargo.icon, color: cargo.color, size: 20),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(cargo.label,
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                      ),
                      Text(Fmt.currency(order.shippingFee),
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                    ]),
                    const SizedBox(height: 4),
                    if (attention) ...[
                      // ── Dòng cảnh báo thay cho chấm trạng thái mặc định ──
                      Row(children: [
                        Icon(Icons.error_rounded, size: 13, color: c.danger),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Chưa tìm được tài xế — cần kiểm tra lại',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600, color: c.danger)),
                        ),
                      ]),
                    ] else ...[
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(Fmt.orderStatus(order.status),
                            style: TextStyle(fontSize: 11.5,
                                fontWeight: FontWeight.w600, color: statusColor)),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: c.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(order.deliveryAddress,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ),
                      const SizedBox(width: 6),
                      Text(Fmt.timeAgo(order.createdAt),
                          style: TextStyle(fontSize: 11, color: c.textTertiary)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
          // ── Chấm tròn báo hiệu ở góc trái ────────────────────────────
          if (attention)
            Positioned(
              top: 10, left: 10,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
              ),
            ),
        ]),
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
                itemBuilder: (_, i) {
                  final v = vouchers[i];
                  return SizedBox(
                    width: 200,
                    child: VoucherCard(
                      voucher: v,
                      eligible: !(v.isExpired || v.isFull),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: v.code));
                        AppSnackbar.success(context, 'Đã sao chép: ${v.code}',
                            duration: const Duration(seconds: 2));
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      },
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
