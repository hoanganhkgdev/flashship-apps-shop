import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/auth/providers/cities_provider.dart';
import 'package:flashship_shop/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isInitialized: true));

  @override
  void clearError() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('register screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth()),
          citiesProvider.overrideWith(
            (ref) async => const [
              CityItem(
                id: 1,
                name: 'Thành phố Hồ Chí Minh',
                lat: 10.77,
                lng: 106.69,
              ),
            ],
          ),
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
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký cửa hàng'), findsOneWidget);
    expect(find.text('Bắt đầu cùng Flash Ship'), findsOneWidget);
    expect(find.text('Tên cửa hàng'), findsOneWidget);
    expect(find.text('Thành phố Hồ Chí Minh'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Gửi mã xác nhận'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
