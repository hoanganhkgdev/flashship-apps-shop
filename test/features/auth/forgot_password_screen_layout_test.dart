import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isInitialized: true));

  @override
  Future<String?> sendForgotPasswordOtp(String phone) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('forgot password steps stay responsive with large text',
      (tester) async {
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
          home: const ForgotPasswordScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Bạn không thể đăng nhập?'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, '0909123456');
    await tester.tap(find.text('Gửi mã OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Đặt lại mật khẩu'), findsWidgets);
    expect(find.text('0909 123 456'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(8));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
