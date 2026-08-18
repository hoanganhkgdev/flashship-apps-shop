import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api/api_client.dart';
import 'core/api/session_expired_notifier.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_form_widgets.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/order/providers/order_provider.dart';
import 'features/security/pin_lock_screen.dart';
import 'features/security/providers/pin_provider.dart';
import 'features/version/providers/app_version_provider.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const ProviderScope(child: FlashShipShopApp()));
}

class FlashShipShopApp extends ConsumerStatefulWidget {
  const FlashShipShopApp({super.key});

  @override
  ConsumerState<FlashShipShopApp> createState() => _FlashShipShopAppState();
}

class _FlashShipShopAppState extends ConsumerState<FlashShipShopApp>
    with WidgetsBindingObserver {

  bool _forceDialogShown = false;
  bool _handlingSessionExpired = false;
  StreamSubscription<void>? _sessionExpiredSub;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.init();
    });
    _sessionExpiredSub =
        SessionExpiredNotifier.stream.listen((_) => _onSessionExpired());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionExpiredSub?.cancel();
    super.dispose();
  }

  // Xử lý tập trung khi bất kỳ API call nào trả 401 ngoài các endpoint auth
  // loại trừ (xem _sessionExemptPaths trong api_client.dart) — tự đăng xuất,
  // báo cho user, điều hướng về /login. Guard 2 lớp: _handlingSessionExpired
  // chặn nhiều 401 gần như đồng thời (vd nhiều request song song lúc app vừa
  // resume) xử lý trùng lặp; kiểm tra isAuthenticated chặn các 401 lặp lại
  // SAU khi đã đăng xuất (lúc đó không còn token nên request nào cũng 401).
  Future<void> _onSessionExpired() async {
    if (_handlingSessionExpired) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    _handlingSessionExpired = true;
    try {
      await ref.read(authProvider.notifier).logout();
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        AppSnackbar.error(ctx, 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
      }
      // _AuthListenable trong app_router.dart đã tự redirect về /login khi
      // authProvider đổi trạng thái — gọi thêm ở đây cho tường minh/chắc chắn.
      ref.read(routerProvider).go('/login');
    } finally {
      _handlingSessionExpired = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      // Đóng socket cũ trước — tránh request bị treo do tái dùng connection
      // mà OS đã đóng băng trong lúc app ở nền lâu.
      ref.read(apiClientProvider).resetConnection();

      final auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        ref.read(authProvider.notifier).refreshUser();
        ref.read(orderListProvider.notifier).fetch(refresh: true);
      }
      _forceDialogShown = false;
      ref.read(appVersionProvider.notifier).check();
      _maybeShowPinLock();
    }
  }

  // Hiện màn khoá PIN khi app quay lại từ nền sau khi đã ở nền tối thiểu 30s
  // — tránh khoá phiền lúc chỉ chuyển app rồi quay lại ngay (vd mở app chụp
  // ảnh, chọn địa chỉ trên bản đồ ngoài app...).
  Future<void> _maybeShowPinLock() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;
    if (DateTime.now().difference(backgroundedAt) < const Duration(seconds: 30)) return;

    final pin = ref.read(pinProvider);
    if (!pin.isEnabled || !pin.hasPin) return;
    if (pinLockScreenVisible) return;

    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    await Navigator.of(ctx, rootNavigator: true).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PinLockScreen()),
    );
  }

  void _showForceDialog(AppVersionState v) {
    if (_forceDialogShown) return;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    _forceDialogShown = true;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final c = dialogCtx.colors;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset('assets/images/logo.png', color: Colors.white, fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Text('Cập nhật bắt buộc',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
            ]),
            content: Text(v.message,
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5)),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _openStore(v.storeUrl),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  child: const Text('Cập nhật ngay',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AppVersionState>(appVersionProvider, (prev, next) {
      if (next.needsForceUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showForceDialog(next));
      }
    });

    return MaterialApp.router(
      title: 'Flash Shop',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child!,
      ),
    );
  }
}
