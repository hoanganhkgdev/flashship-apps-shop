import 'package:flashship_shop/features/order/utils/create_batch_order_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validStop = BatchStopValidationInput(
    address: 'Điểm giao',
    phone: '0900000000',
    lat: 10,
    lng: 106,
  );

  test('requires a resolved shop pickup address', () {
    expect(
      CreateBatchOrderValidator.validate(
        pickupAddress: 'Shop',
        pickupLat: null,
        pickupLng: null,
        stops: const [validStop],
      ),
      contains('chọn địa chỉ cửa hàng'),
    );
  });

  test('identifies the first incomplete stop', () {
    expect(
      CreateBatchOrderValidator.validate(
        pickupAddress: 'Shop',
        pickupLat: 10,
        pickupLng: 106,
        stops: const [
          validStop,
          BatchStopValidationInput(address: '', phone: '', lat: 10, lng: 106),
        ],
      ),
      'Điểm 2: cần nhập địa chỉ và SĐT',
    );
  });

  test('returns no error for a complete batch', () {
    expect(
      CreateBatchOrderValidator.validate(
        pickupAddress: 'Shop',
        pickupLat: 10,
        pickupLng: 106,
        stops: const [validStop],
      ),
      isNull,
    );
  });
}
