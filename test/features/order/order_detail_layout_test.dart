import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/order/data/order_repository.dart';
import 'package:flashship_shop/features/order/models/order_model.dart';
import 'package:flashship_shop/features/order/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OrderRepository implements OrderRepository {
  const _OrderRepository(this.order);

  final OrderModel order;

  @override
  Future<OrderModel> findByCode(String code) async => order;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('order detail stays responsive with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = OrderModel(
      id: 1,
      code: 'FS1001',
      status: 'completed',
      pickupAddress: '12 Nguyễn Trãi, Dương Đông, Phú Quốc',
      pickupPhone: '0909000001',
      storeName: 'Cửa hàng Nhà Mình',
      deliveryAddress: '25 Trần Hưng Đạo, Dương Đông, Phú Quốc',
      deliveryPhone: '0909000002',
      receiverName: 'Nguyễn Văn An',
      shippingFee: 25000,
      codAmount: 450000,
      discountAmount: 10000,
      distanceKm: 5.4,
      driverRating: 5,
      createdAt: DateTime(2026, 10, 29, 9, 30),
      completedAt: DateTime(2026, 10, 29, 10, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(_OrderRepository(order)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const OrderDetailScreen(orderCode: 'FS1001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    expect(find.text('#FS1001'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Chi tiết thanh toán'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiền thu hộ'), findsOneWidget);
    expect(find.text('Phí giao hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
