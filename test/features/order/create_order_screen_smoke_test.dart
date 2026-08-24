import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/screens/create_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the order form above the submit bar', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateOrderScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Giao hàng'), findsOneWidget);
    expect(find.text('ĐIỂM LẤY HÀNG'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO HÀNG'), findsOneWidget);
    expect(find.text('SĐT người nhận'), findsOneWidget);
    expect(find.text('Đặt đơn'), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      greaterThan(500),
    );
    expect(tester.takeException(), isNull);
  });
}
