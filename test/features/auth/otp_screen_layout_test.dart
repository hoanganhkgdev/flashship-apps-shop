import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/auth/screens/otp_screen.dart';
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
  testWidgets('otp screen stays responsive with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((ref) => _Auth())],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const OtpScreen(
            regData: {
              'phone': '0909123456',
              'name': 'Shop Test',
              'password': '123456',
              'city_id': 1,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Xác nhận OTP'), findsOneWidget);
    expect(find.text('0909 123 456'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('Xác nhận mã'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Xác nhận mã'));
    await tester.pump();
    expect(find.text('Vui lòng nhập đủ 6 chữ số'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
