import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/models/order_model.dart';
import 'package:flashship_shop/features/order/utils/order_reorder.dart';
import 'package:flashship_shop/features/order/widgets/order_driver_row.dart';
import 'package:flashship_shop/features/order/widgets/order_route_lines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order({
  String status = 'completed',
  bool isBatch = false,
  String? shopServiceType,
  List<Map<String, dynamic>> stops = const [],
  DriverInfo? driver,
}) =>
    OrderModel(
      id: 1,
      code: 'FS123',
      status: status,
      pickupAddress: '1 Nguyễn Huệ',
      pickupLat: 10.1,
      pickupLng: 106.1,
      pickupPhone: '0900000001',
      senderName: 'Shop A',
      deliveryAddress: '2 Lê Lợi',
      deliveryLat: 10.2,
      deliveryLng: 106.2,
      deliveryPhone: '0900000002',
      receiverName: 'Khách B',
      shippingFee: 25000,
      orderNote: 'Gọi trước khi giao',
      cargoType: 'food',
      isBatch: isBatch,
      shopServiceType: shopServiceType,
      stops: stops,
      createdAt: DateTime(2026, 10, 1),
      driver: driver,
    );

void main() {
  test('reorderExtra copies route, contacts, cargo and note', () {
    final extra = reorderExtra(_order());

    expect(extra['isOutbound'], isTrue);
    expect(extra['pickupAddr'], '1 Nguyễn Huệ');
    expect(extra['deliveryAddr'], '2 Lê Lợi');
    expect(extra['deliveryPhone'], '0900000002');
    expect(extra['deliveryName'], 'Khách B');
    expect(extra['cargoType'], 'food');
    expect(extra['note'], 'Gọi trước khi giao');
  });

  test('reorderExtra marks shop pickup orders as inbound', () {
    expect(reorderExtra(_order(shopServiceType: 'shop_pickup'))['isOutbound'],
        isFalse);
  });

  test('reorderBatchExtra keeps every stop and drops the pickup phone', () {
    final extra = reorderBatchExtra(_order(isBatch: true, stops: [
      {'address': 'A', 'lat': 1.0, 'lng': 2.0, 'phone': '1', 'cod_amount': 5000},
      {'address': 'B', 'phone': '2'},
    ]));

    expect((extra['stops'] as List).length, 2);
    expect((extra['stops'] as List).first['codAmount'], 5000);
    expect(extra.containsKey('pickupPhone'), isFalse);
  });

  testWidgets('route lines show pickup and delivery', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: OrderRouteLines(pickup: '1 Nguyễn Huệ', delivery: '2 Lê Lợi'),
      ),
    ));

    expect(find.text('1 Nguyễn Huệ'), findsOneWidget);
    expect(find.text('2 Lê Lợi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver row shows the name and a call button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: OrderDriverRow(
            driver: DriverInfo(id: 9, name: 'Tài xế Nam', phone: '0911111111')),
      ),
    ));

    expect(find.text('Tài xế Nam'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
  });
}
