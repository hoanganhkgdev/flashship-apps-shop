import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/security/pin_setup_screen.dart';
import 'package:flashship_shop/features/security/providers/pin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pin extends StateNotifier<PinState> implements PinNotifier {
  _Pin() : super(const PinState(isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('PIN setup stays responsive on a small screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinProvider.overrideWith((ref) => _Pin())],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const PinSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thiết lập mã PIN'), findsOneWidget);
    expect(find.text('Tạo mã PIN'), findsOneWidget);
    expect(find.text('Bước 1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.scrollUntilVisible(
        find.text(digit),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text(digit));
      await tester.pump();
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận mã PIN'), findsOneWidget);
    expect(find.text('Bước 2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
