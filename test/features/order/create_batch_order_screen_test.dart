import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/data/order_repository.dart';
import 'package:flashship_shop/features/order/screens/create_batch_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, List<DestinationPrice> options) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        destinationPricesProvider.overrideWith((ref) async => options),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CreateBatchOrderScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('each stop can pick a fixed-price delivery area', (tester) async {
    await _pump(tester, const [
      DestinationPrice(id: 1, name: 'Sân bay', fee: 55000),
    ]);

    expect(find.text('Khu vực giao: tự tính theo quãng đường'), findsOneWidget);

    await tester.tap(find.text('Khu vực giao: tự tính theo quãng đường'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sân bay'));
    await tester.pumpAndSettle();

    expect(find.text('Khu vực giao: Sân bay · 55.000đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the area row when the city has no fixed prices',
      (tester) async {
    await _pump(tester, const []);

    expect(find.textContaining('Khu vực giao'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
