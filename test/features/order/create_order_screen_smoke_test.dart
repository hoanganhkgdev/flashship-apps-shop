import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/data/order_repository.dart';
import 'package:flashship_shop/features/order/screens/create_order_screen.dart';
import 'package:flashship_shop/features/order/models/shop_order_type.dart';
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
        overrides: [
          destinationPricesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateOrderScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Giao hàng'), findsOneWidget);
    expect(find.text('Lấy hàng'), findsNothing);
    expect(find.text('ĐIỂM LẤY HÀNG'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO HÀNG'), findsOneWidget);
    expect(find.text('SĐT người nhận'), findsOneWidget);
    expect(find.text('Đặt đơn'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      greaterThan(500),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps pickup flow fixed without an order type switch',
      (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationPricesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateOrderScreen(orderType: ShopOrderType.pickup),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lấy hàng'), findsOneWidget);
    expect(find.text('Giao hàng'), findsNothing);
    expect(find.text('SĐT người giao'), findsOneWidget);
    expect(find.text('Chọn địa chỉ cửa hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows the destination picker only when the city has fixed prices',
      (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationPricesProvider.overrideWith((ref) async => const [
                DestinationPrice(id: 1, name: 'Sân bay', fee: 55000),
                DestinationPrice(
                    id: 2, name: 'Bãi Thơm', fee: 150000, feeMax: 180000),
              ]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateOrderScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('KHU VỰC GIAO (GIÁ CỐ ĐỊNH)'), findsOneWidget);
    expect(find.text('Tự tính theo quãng đường'), findsOneWidget);

    await tester.tap(find.text('KHU VỰC GIAO (GIÁ CỐ ĐỊNH)'));
    await tester.pumpAndSettle();

    expect(find.text('Sân bay'), findsOneWidget);
    expect(find.text('Bãi Thơm'), findsOneWidget);
    expect(find.text('Tối đa 180.000đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
