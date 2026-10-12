import 'package:flashship_shop/features/order/models/shop_order_type.dart';
import 'package:flashship_shop/features/order/utils/create_order_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires both addresses before coordinates', () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: null,
        deliveryAddress: 'Khách',
        pickupLat: null,
        pickupLng: null,
        deliveryLat: 10,
        deliveryLng: 106,
      ),
      'Vui lòng chọn điểm lấy và điểm giao',
    );
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

  test('delivery does not require the receiver phone', () {
    expect(
      CreateOrderValidator.contacts(
        orderType: ShopOrderType.delivery,
        receiverPhone: '',
        senderPhone: '',
      ),
      isNull,
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
