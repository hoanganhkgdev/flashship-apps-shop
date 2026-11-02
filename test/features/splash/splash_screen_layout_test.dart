import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/splash/splash_screen.dart';
import 'package:flashship_shop/features/version/providers/app_version_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Version extends StateNotifier<AppVersionState>
    implements AppVersionNotifier {
  _Version() : super(const AppVersionState());

  @override
  Future<void> check() async {
    state = const AppVersionState(isChecked: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('splash stays responsive on a small screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWith((ref) => _Version())],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Dành cho đối tác cửa hàng'), findsOneWidget);
    expect(find.text('Flash Ship'), findsOneWidget);
    expect(
      find.text('Giao hàng nhanh, vận hành cửa hàng nhẹ nhàng'),
      findsOneWidget,
    );
    expect(find.text('Tạo đơn nhanh'), findsOneWidget);
    expect(find.text('Đang chuẩn bị không gian bán hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
