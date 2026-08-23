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
import '../../order/models/shop_order_type.dart';
import '../../order/providers/order_provider.dart';
import '../../order/screens/order_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../stats/stats_screen.dart';
import '../providers/today_stats_provider.dart';
import '../../version/providers/app_version_provider.dart';
import '../../voucher/voucher_provider.dart';
import '../../voucher/widgets/voucher_card.dart';
import '../widgets/create_order_card.dart';

part '../widgets/dashboard_tab.dart';
part '../widgets/dashboard_header.dart';
part '../widgets/dashboard_banners.dart';
part '../widgets/frequent_address_section.dart';
part '../widgets/dashboard_order_card.dart';
part '../widgets/dashboard_voucher_section.dart';

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
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            body: body,
            orderCode: orderCode,
            createdAt: DateTime.now(),
          ));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty)
                Text(body, style: const TextStyle(fontSize: 13)),
            ]),
        action: orderCode != null
            ? SnackBarAction(
                label: 'Xem',
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
    AppNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Trang chủ'),
    AppNavItem(
        icon: Icons.list_alt_outlined,
        activeIcon: Icons.list_alt_rounded,
        label: 'Đơn hàng'),
    AppNavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        label: 'Thống kê'),
    AppNavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Cửa hàng'),
  ];

  static const _pages = [
    _DashboardTab(),
    OrderListScreen(),
    StatsScreen(),
    ProfileScreen()
  ];

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
