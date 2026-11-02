import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/address/models/address_entry.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/address/screens/address_book_screen.dart';
import '../../features/notification/screens/notification_inbox_screen.dart';
import '../../features/order/screens/create_batch_order_screen.dart';
import '../../features/order/screens/create_order_screen.dart';
import '../../features/order/screens/order_detail_screen.dart';
import '../../features/order/models/shop_order_type.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/security/pin_lock_screen.dart';
import '../../features/security/providers/pin_provider.dart';
import '../../features/referral/referral_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/voucher/voucher_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/version/providers/app_version_provider.dart';
import '../widgets/app_decor_widgets.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Trang của router: mỗi màn tự vẽ nền đặc của app. Các màn hình để nền trong
/// suốt (nền chung vẽ một lần phía ngoài Navigator), nên nếu không có nền riêng
/// thì khi chuyển màn, màn cũ vẫn hiện xuyên qua màn mới trong lúc trượt.
Page<void> _page(GoRouterState state, Widget child) => appPage(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      arguments: state.extra,
      child: child,
    );

Page<void> appPage({
  required LocalKey key,
  required Widget child,
  String? name,
  Object? arguments,
}) =>
    MaterialPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      child: AppBackdrop(child: child),
    );

// Splash chờ khởi tạo và một nhịp hiển thị thương hiệu ngắn trước khi điều hướng.
final splashReadyProvider = StateProvider<bool>((ref) => false);

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<AppVersionState>(
        appVersionProvider, (_, __) => notifyListeners());
    ref.listen<bool>(splashReadyProvider, (_, __) => notifyListeners());
    ref.listen<PinState>(pinProvider, (_, __) => notifyListeners());
    ref.listen<bool>(pinLockPassedProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: listenable,
    // Firebase Phone Auth (reCAPTCHA/APNs) mở lại app bằng deep link
    // `<scheme>://firebaseauth/link...`; plugin tự xử lý, router bỏ qua để
    // người dùng ở nguyên màn đang xác minh số (cùng cách làm với app customer).
    onException: (context, state, router) {
      if (state.uri.host == 'firebaseauth') return;
      router.go('/splash');
    },
    redirect: (context, state) {
      // Không redirect link Firebase — nếu không, nhánh "chưa đăng nhập" bên
      // dưới sẽ đẩy về /login ngay giữa lúc đang gửi mã xác minh.
      if (state.uri.host == 'firebaseauth') return null;
      final auth = ref.read(authProvider);
      final version = ref.read(appVersionProvider);
      final pin = ref.read(pinProvider);
      final location = state.matchedLocation;

      final splashReady = ref.read(splashReadyProvider);
      if (!auth.isInitialized || !pin.isInitialized || !splashReady) {
        return location == '/splash' ? null : '/splash';
      }
      if (version.needsForceUpdate) return '/splash';

      final isAuth = auth.isAuthenticated;
      final onSplash = location == '/splash';
      final onAuth = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';
      final onPinLock = location == '/pin-lock';

      // Yêu cầu nhập PIN khi: đã đăng nhập, đang bật khoá PIN, đã thiết lập
      // PIN, và chưa qua màn khoá lần nào trong phiên app hiện tại (cold start).
      final needsPinLock = isAuth &&
          pin.isEnabled &&
          pin.hasPin &&
          !ref.read(pinLockPassedProvider);

      if (onSplash) {
        if (!isAuth) return '/login';
        return needsPinLock ? '/pin-lock' : '/home';
      }
      if (isAuth && onAuth) return '/home';
      if (needsPinLock && !onPinLock) return '/pin-lock';
      if (!needsPinLock && onPinLock) return '/home';
      if (!isAuth && !onSplash && !onAuth && location != '/otp') {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/splash',
          pageBuilder: (_, state) => _page(state, const SplashScreen())),
      GoRoute(
          path: '/login',
          pageBuilder: (_, state) => _page(state, const LoginScreen())),
      GoRoute(
          path: '/register',
          pageBuilder: (_, state) => _page(state, const RegisterScreen())),
      GoRoute(
          path: '/forgot-password',
          pageBuilder: (_, state) =>
              _page(state, const ForgotPasswordScreen())),
      GoRoute(
        path: '/otp',
        pageBuilder: (_, state) => _page(
            state, OtpScreen(regData: state.extra as Map<String, dynamic>)),
      ),
      GoRoute(
          path: '/home',
          pageBuilder: (_, state) => _page(state, const HomeScreen())),
      GoRoute(
        path: '/pin-lock',
        pageBuilder: (_, state) => _page(
          state,
          PinLockScreen(
            onUnlocked: () =>
                ref.read(pinLockPassedProvider.notifier).state = true,
          ),
        ),
      ),
      GoRoute(
        path: '/create-batch',
        pageBuilder: (_, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return _page(state, CreateBatchOrderScreen(reorderFrom: extra));
          }
          return _page(state, const CreateBatchOrderScreen());
        },
      ),
      GoRoute(
        path: '/create-order',
        pageBuilder: (_, state) {
          final extra = state.extra;
          if (extra is ShopOrderType) {
            return _page(state, CreateOrderScreen(orderType: extra));
          }
          if (extra is bool) {
            return _page(
              state,
              CreateOrderScreen(
                orderType:
                    extra ? ShopOrderType.delivery : ShopOrderType.pickup,
              ),
            );
          }
          if (extra is AddressEntry) {
            return _page(state, CreateOrderScreen(prefillDelivery: extra));
          }
          if (extra is Map<String, dynamic>) {
            return _page(
              state,
              CreateOrderScreen(
                orderType: (extra['isOutbound'] as bool? ?? true)
                    ? ShopOrderType.delivery
                    : ShopOrderType.pickup,
                reorderFrom: extra,
              ),
            );
          }
          return _page(state, const CreateOrderScreen());
        },
      ),
      GoRoute(
        path: '/order/:code',
        pageBuilder: (_, state) => _page(
            state, OrderDetailScreen(orderCode: state.pathParameters['code']!)),
      ),
      GoRoute(
          path: '/stats',
          pageBuilder: (_, state) => _page(state, const StatsScreen())),
      GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => _page(state, const ProfileScreen())),
      GoRoute(
          path: '/notifications',
          pageBuilder: (_, state) =>
              _page(state, const NotificationInboxScreen())),
      GoRoute(
          path: '/address-book',
          pageBuilder: (_, state) => _page(state, const AddressBookScreen())),
      GoRoute(
          path: '/vouchers',
          pageBuilder: (_, state) => _page(state, const VoucherScreen())),
      GoRoute(
          path: '/referral',
          pageBuilder: (_, state) => _page(state, const ReferralScreen())),
    ],
  );
});
