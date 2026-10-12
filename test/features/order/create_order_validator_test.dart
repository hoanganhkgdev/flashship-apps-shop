import 'package:flashship_shop/features/order/models/shop_order_type.dart';
import 'package:flashship_shop/features/order/utils/create_order_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires the pickup point first', () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: null,
        deliveryAddress: 'Khách',
        pickupLat: null,
        pickupLng: null,
        deliveryLat: 10,
        deliveryLng: 106,
      ),
      'Vui lòng chọn điểm lấy hàng',
    );
  });

  group('the delivery point needs an address or a delivery area', () {
    String? check({
      String? address,
      bool area = false,
      bool areasAvailable = false,
      double? lat,
    }) =>
        CreateOrderValidator.locations(
          pickupAddress: 'Shop',
          deliveryAddress: address,
          pickupLat: 10,
          pickupLng: 106,
          deliveryLat: lat,
          deliveryLng: lat,
          hasDestination: area,
          areasAvailable: areasAvailable,
        );

    test('neither one is rejected and the message mentions the area', () {
      expect(check(areasAvailable: true),
          'Vui lòng nhập địa chỉ giao hàng hoặc chọn khu vực giao');
    });

    test('neither one without areas to choose only asks for the point', () {
      expect(check(), 'Vui lòng chọn điểm giao');
    });

    test('a delivery area alone is enough', () {
      expect(check(area: true, areasAvailable: true), isNull);
    });

    test('an address with coordinates alone is enough', () {
      expect(check(address: 'Khách', lat: 10, areasAvailable: true), isNull);
    });

    test('an address still needs its coordinates when no area is chosen', () {
      expect(check(address: 'Khách'), contains('Đang xác định toạ độ'));
    });

    test('both together are fine', () {
      expect(check(address: 'Khách', area: true, areasAvailable: true), isNull);
    });
  });

  test('a chosen delivery area replaces the delivery address and coordinates',
      () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: 'Shop',
        deliveryAddress: null,
        pickupLat: 10,
        pickupLng: 106,
        deliveryLat: null,
        deliveryLng: null,
        hasDestination: true,
      ),
      isNull,
    );
  });

  test('a chosen delivery area still requires the pickup point', () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: null,
        deliveryAddress: null,
        pickupLat: null,
        pickupLng: null,
        deliveryLat: null,
        deliveryLng: null,
        hasDestination: true,
      ),
      'Vui lòng chọn điểm lấy hàng',
    );
  });

  test('requires resolved coordinates', () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: 'Shop',
        deliveryAddress: 'Khách',
        pickupLat: 10,
        pickupLng: 106,
        deliveryLat: null,
        deliveryLng: null,
      ),
      contains('Đang xác định toạ độ'),
    );
  });

  test('pickup requires contact at pickup point', () {
    expect(
      CreateOrderValidator.contacts(
        orderType: ShopOrderType.pickup,
        receiverPhone: '0900000001',
        senderPhone: '',
      ),
      'Vui lòng nhập SĐT liên hệ tại điểm lấy',
    );
  });

  test('delivery requires the receiver phone', () {
    expect(
      CreateOrderValidator.contacts(
        orderType: ShopOrderType.delivery,
        receiverPhone: '  ',
        senderPhone: '',
      ),
      'Vui lòng nhập SĐT người nhận',
    );
  });

  test('pickup still requires the shop phone', () {
    expect(
      CreateOrderValidator.contacts(
        orderType: ShopOrderType.pickup,
        receiverPhone: '  ',
        senderPhone: '0900000002',
      ),
      'Vui lòng nhập SĐT cửa hàng',
    );
  });

  test('valid delivery contacts return no error', () {
    expect(
      CreateOrderValidator.contacts(
        orderType: ShopOrderType.delivery,
        receiverPhone: '0900000001',
        senderPhone: '',
      ),
      isNull,
    );
  });
}
