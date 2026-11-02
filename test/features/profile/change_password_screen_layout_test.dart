import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/profile/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('change password screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const ChangePasswordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Cập nhật mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Yêu cầu mật khẩu'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cập nhật mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập mật khẩu hiện tại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
