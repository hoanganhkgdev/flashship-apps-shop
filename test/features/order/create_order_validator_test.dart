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

  test('requires the delivery point', () {
    expect(
      CreateOrderValidator.locations(
        pickupAddress: 'Shop',
        deliveryAddress: null,
        pickupLat: 10,
        pickupLng: 106,
        deliveryLat: null,
        deliveryLng: null,
      ),
      'Vui lòng chọn điểm giao',
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
