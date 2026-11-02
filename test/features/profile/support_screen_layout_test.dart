import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/profile/models/support_config_item.dart';
import 'package:flashship_shop/features/profile/providers/support_config_provider.dart';
import 'package:flashship_shop/features/profile/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportConfigProvider.overrideWith(
            (ref) async => const [
              SupportConfigItem(
                title: 'Tổng đài FlashShip',
                type: 'phone',
                value: '0909123456',
              ),
              SupportConfigItem(
                title: 'Email hỗ trợ',
                type: 'email',
                value: 'support@flashship.vn',
              ),
              SupportConfigItem(
                title: 'Zalo FlashShip',
                type: 'zalo',
                value: '0909123456',
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
          home: const SupportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Liên hệ hỗ trợ'), findsOneWidget);
    expect(find.text('Bạn cần hỗ trợ?'), findsOneWidget);
    expect(find.text('Tổng đài FlashShip'), findsOneWidget);
    expect(find.text('Email hỗ trợ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Lưu ý bảo mật'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Lưu ý bảo mật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
