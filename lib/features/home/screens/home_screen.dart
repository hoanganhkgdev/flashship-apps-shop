import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/store_launcher.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/quick_action_bar.dart';
import '../../../core/widgets/stat_row.dart';
import '../../../core/widgets/status_badge.dart';
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

            // ── Dịch vụ (quick actions) ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Dịch vụ',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: QuickActionBar(items: [
                  QuickAction(
                    icon:  Icons.local_shipping_outlined,
                    color: c.success,
                    label: 'Giao đơn',
                    onTap: () => context.push('/create-order', extra: true),
                  ),
                  QuickAction(
                    icon:  Icons.location_on_outlined,
                    color: c.info,
                    label: 'Lấy hộ',
                    onTap: () => context.push('/create-order', extra: false),
                  ),
                  QuickAction(
                    icon:  Icons.layers_outlined,
                    color: c.success,
                    label: 'Đơn gộp',
                    onTap: () => context.push('/create-batch'),
                  ),
                ]),
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
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: c.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ...active.take(5).toList().asMap().entries.map((e) {
                        final i = e.key;
                        return Column(children: [
                          _OrderCard(key: ValueKey(e.value.code), order: e.value),
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

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Dải màu thương hiệu mỏng — điểm nhấn duy nhất trên nền trắng ──
      Container(height: 3, color: c.primary),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Tên shop + bell ────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Text(shopName,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: c.textPrimary, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              // ── Bell icon với badge ──────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/notifications'),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.notifications_outlined,
                        color: c.textPrimary, size: 20),
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
            if (shopAddress.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_rounded, size: 12, color: c.textTertiary),
                const SizedBox(width: 2),
                Flexible(child: Text(shopAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary))),
              ]),
            ],

            // ── Stats hôm nay ──────────────────────────────────────────
            if (today != null) ...[
              const SizedBox(height: 16),
              StatRow(items: [
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
            ],
          ]),
        ),
      ),
    ]);
  }
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
          border: Border.all(color: c.divider),
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

    return InkWell(
      onTap: () => context.push('/order/${order.code}'),
      child: Stack(children: [
        Padding(
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
                      child: Text(cargo.label,
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
                  if (attention) ...[
                    // ── Dòng cảnh báo thay cho badge trạng thái mặc định ──
                    Row(children: [
                      Icon(Icons.error_rounded, size: 14, color: c.danger),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Chưa tìm được tài xế — cần kiểm tra lại',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: c.danger)),
                      ),
                      const SizedBox(width: 6),
                      Text(Fmt.timeAgo(order.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: c.textSecondary)),
                    ]),
                  ] else ...[
                    Row(children: [
                      StatusBadge(
                          label: Fmt.orderStatus(order.status),
                          color: statusColor),
                      const Spacer(),
                      Text(Fmt.timeAgo(order.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: c.textSecondary)),
                    ]),
                  ],
                ],
              ),
            ),
          ]),
          ),
        ),
        // ── Chấm tròn báo hiệu ở góc trái ────────────────────────────────
        if (attention)
          Positioned(
            top: 10, left: 10,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
            ),
          ),
      ]),
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
            border: Border.all(color: c.divider)),
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
