import 'package:flashship_shop/features/order/data/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses nearby driver map data into a typed model', () {
    final driver = NearbyDriver.fromJson({
      'id': 12,
      'lat': 10.75,
      'lng': 106.67,
      'bearing': 45,
    });

    expect(driver.id, 12);
    expect(driver.lat, 10.75);
    expect(driver.lng, 106.67);
    expect(driver.bearing, 45);
  });

  test('serializes the existing shop order API contract', () {
    const request = CreateOrderRequest(
      isOutbound: false,
      pickupAddress: 'Điểm lấy',
      deliveryAddress: 'Cửa hàng',
      deliveryPhone: '0900000001',
      deliveryName: 'Shop',
      pickupName: 'Nhà cung cấp',
      pickupPhone: '0900000002',
      orderNote: 'Hàng dễ vỡ',
      cargoType: 'parcel',
      cargoWeight: 2.5,
      codAmount: 150000,
      pickupLat: 10.1,
      pickupLng: 106.1,
      deliveryLat: 10.2,
      deliveryLng: 106.2,
      voucherCode: 'SAVE10',
    );

    expect(request.toJson(), {
      'is_outbound': 0,
      'pickup_address': 'Điểm lấy',
      'delivery_address': 'Cửa hàng',
      'delivery_phone': '0900000001',
      'delivery_name': 'Shop',
      'pickup_name': 'Nhà cung cấp',
      'pickup_phone': '0900000002',
      'order_note': 'Hàng dễ vỡ',
      'cargo_note': 'Hàng dễ vỡ',
      'cargo_type': 'parcel',
      'cargo_weight': 2.5,
      'cod_amount': 150000,
      'pickup_lat': 10.1,
      'pickup_lng': 106.1,
      'delivery_lat': 10.2,
      'delivery_lng': 106.2,
      'voucher_code': 'SAVE10',
    });
  });

  test('omits optional empty values', () {
    const request = CreateOrderRequest(
      isOutbound: true,
      pickupAddress: 'Shop',
      deliveryAddress: 'Khách',
      deliveryPhone: '0900000000',
      deliveryName: '',
      orderNote: '',
      cargoType: 'food',
    );

    expect(request.toJson(), {
      'is_outbound': 1,
      'pickup_address': 'Shop',
      'delivery_address': 'Khách',
      'delivery_phone': '0900000000',
      'cargo_type': 'food',
    });
  });

  test('serializes the batch order API contract', () {
    const request = CreateBatchOrderRequest(
      pickupAddress: 'Shop',
      pickupPhone: '0900000000',
      orderNote: 'Giao theo thứ tự',
      cargoType: 'food',
      pickupLat: 10.1,
      pickupLng: 106.1,
      voucherCode: 'BATCH10',
      stops: [
        CreateBatchStopRequest(
          address: 'Điểm 1',
          phone: '0900000001',
          name: 'Khách 1',
          note: '',
          lat: 10.2,
          lng: 106.2,
          codAmount: 50000,
        ),
      ],
    );

    expect(request.toJson(), {
      'pickup_address': 'Shop',
      'pickup_phone': '0900000000',
      'order_note': 'Giao theo thứ tự',
      'cargo_type': 'food',
      'pickup_lat': 10.1,
      'pickup_lng': 106.1,
      'voucher_code': 'BATCH10',
      'stops': [
        {
          'address': 'Điểm 1',
          'phone': '0900000001',
          'name': 'Khách 1',
          'note': '',
          'lat': 10.2,
          'lng': 106.2,
          'cod_amount': 50000,
        },
      ],
    });
  });
}
