import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/auth/screens/login_screen.dart';
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
  testWidgets('login screen stays responsive with large text', (tester) async {
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
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('số điện thoại'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
