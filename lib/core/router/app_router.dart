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
import '../../features/profile/screens/profile_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/version/providers/app_version_provider.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

// Đảm bảo splash hiện tối thiểu 2 giây
final splashReadyProvider = StateProvider<bool>((ref) => false);

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<AppVersionState>(appVersionProvider, (_, __) => notifyListeners());
    ref.listen<bool>(splashReadyProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth     = ref.read(authProvider);
      final version  = ref.read(appVersionProvider);
      final location = state.matchedLocation;

      final splashReady = ref.read(splashReadyProvider);
      if (!auth.isInitialized || !splashReady) return location == '/splash' ? null : '/splash';
      if (version.needsForceUpdate) return '/splash';

      final isAuth  = auth.isAuthenticated;
      final onSplash = location == '/splash';
      final onAuth   = location == '/login' || location == '/register' || location == '/forgot-password';

      if (onSplash) return isAuth ? '/home' : '/login';
      if (isAuth && onAuth) return '/home';
      if (!isAuth && !onSplash && !onAuth && location != '/otp') return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',        builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(regData: state.extra as Map<String, dynamic>),
      ),
      GoRoute(path: '/home',         builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/create-batch', builder: (_, __) => const CreateBatchOrderScreen()),
      GoRoute(
        path: '/create-order',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is bool) {
            return CreateOrderScreen(isOutbound: extra);
          }
          if (extra is AddressEntry) {
            return CreateOrderScreen(isOutbound: true, prefillDelivery: extra);
          }
          if (extra is Map<String, dynamic>) {
            return CreateOrderScreen(
              isOutbound:   extra['isOutbound'] as bool? ?? true,
              reorderFrom:  extra,
            );
          }
          return const CreateOrderScreen(isOutbound: true);
        },
      ),
      GoRoute(
        path: '/order/:code',
        builder: (_, state) => OrderDetailScreen(orderCode: state.pathParameters['code']!),
      ),
      GoRoute(path: '/stats',         builder: (_, __) => const StatsScreen()),
      GoRoute(path: '/profile',       builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/notifications',  builder: (_, __) => const NotificationInboxScreen()),
      GoRoute(path: '/address-book',   builder: (_, __) => const AddressBookScreen()),
    ],
  );
});
