import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/auth/data/auth_repository.dart';
import 'package:flashship_shop/features/profile/screens/devices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthRepository implements AuthRepository {
  @override
  Future<List<LoginDevice>> devices() async => [
        LoginDevice(
          id: 1,
          deviceName: 'iPhone 17 Pro Max',
          location: 'Rạch Giá, Kiên Giang',
          lastActiveAt: DateTime.now(),
          isCurrent: true,
        ),
        LoginDevice(
          id: 2,
          deviceName: 'Samsung Galaxy Tab của cửa hàng',
          location: 'Phú Quốc, Kiên Giang',
          lastActiveAt: DateTime.now().subtract(const Duration(days: 2)),
          isCurrent: false,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('devices screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_AuthRepository()),
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
          home: const DevicesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thiết bị đăng nhập'), findsOneWidget);
    expect(find.text('Thiết bị này'), findsOneWidget);
    expect(find.text('Samsung Galaxy Tab của cửa hàng'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Đăng xuất tất cả thiết bị khác'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất tất cả thiết bị khác'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
