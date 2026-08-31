import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/home/widgets/create_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildCard({
    required VoidCallback onDelivery,
    required VoidCallback onPickup,
    required VoidCallback onBatch,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CreateOrderCard(
              onDeliveryTap: onDelivery,
              onPickupTap: onPickup,
              onBatchTap: onBatch,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the three order actions', (tester) async {
    await tester.pumpWidget(buildCard(
      onDelivery: () {},
      onPickup: () {},
      onBatch: () {},
    ));

    expect(find.text('Giao hàng'), findsOneWidget);
    expect(find.text('Lấy hàng'), findsOneWidget);
    expect(find.text('Đơn gộp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes each action through its own callback', (tester) async {
    var selected = '';
    await tester.pumpWidget(buildCard(
      onDelivery: () => selected = 'delivery',
      onPickup: () => selected = 'pickup',
      onBatch: () => selected = 'batch',
    ));

    await tester.tap(find.text('Giao hàng'));
    expect(selected, 'delivery');
    await tester.tap(find.text('Lấy hàng'));
    expect(selected, 'pickup');
    await tester.tap(find.text('Đơn gộp'));
    expect(selected, 'batch');
  });
}
