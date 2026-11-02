import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/screens/create_batch_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('batch order screen stays responsive with large text',
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
          home: const CreateBatchOrderScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Tạo đơn gộp'), findsOneWidget);
    expect(find.text('Giao nhiều nơi, tạo một lần'), findsOneWidget);
    expect(find.text('Đặt 1 điểm giao'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
