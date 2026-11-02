import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/core/theme/theme_mode_provider.dart';
import 'package:flashship_shop/features/auth/models/shop_user_model.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/profile/screens/profile_screen.dart';
import 'package:flashship_shop/features/security/providers/pin_provider.dart';
import 'package:flashship_shop/features/stats/stats_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
      : super(const AuthState(
          isInitialized: true,
          token: 'token',
          user: ShopUserModel(
            id: 1,
            name: 'Cửa hàng Hoàng Anh',
            phone: '0909123456',
            address: 'Rạch Giá, Kiên Giang',
            cityName: 'Kiên Giang',
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pin extends StateNotifier<PinState> implements PinNotifier {
  _Pin()
      : super(const PinState(
          isInitialized: true,
          hasPin: true,
          isEnabled: true,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Theme extends StateNotifier<ThemeMode> implements ThemeModeNotifier {
  _Theme() : super(ThemeMode.light);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stats implements StatsRepository {
  @override
  Future<Map<String, dynamic>> fetch({String? period}) async => const {
        'revenue': 120000,
        'total': 8,
        'completed': 6,
        'cancelled': 1,
        'daily': <Map<String, dynamic>>[],
      };
}

void main() {
  testWidgets('profile settings stay responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth()),
          pinProvider.overrideWith((ref) => _Pin()),
          themeModeProvider.overrideWith((ref) => _Theme()),
          statsRepositoryProvider.overrideWithValue(_Stats()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settingsEntry = find.text('Thiết lập tài khoản và ứng dụng');
    await tester.scrollUntilVisible(
      settingsEntry,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsWidgets);
    expect(find.text('Tài khoản cửa hàng'), findsOneWidget);
    expect(find.text('Trải nghiệm ứng dụng'), findsOneWidget);
    expect(find.text('Khoá bằng mã PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Chế độ hiển thị'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Chế độ hiển thị'));
    await tester.pumpAndSettle();

    expect(find.text('Giao diện sáng'), findsOneWidget);
    expect(find.text('Giao diện tối'), findsOneWidget);
    expect(find.text('Theo hệ thống'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đổi số điện thoại'));
    await tester.pumpAndSettle();
    expect(find.text('Xác minh số điện thoại mới'), findsOneWidget);
    expect(find.text('Bước 1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
