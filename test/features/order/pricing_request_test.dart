import 'package:flashship_shop/features/order/utils/pricing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a destination alone sends the pickup and destination_id only', () {
    final p = buildPricingParams(
      cargoType: 'food',
      pickupLat: 10,
      pickupLng: 106,
      deliveryLat: null,
      deliveryLng: null,
      pickupAddress: 'Shop',
      deliveryAddress: '',
      destinationId: 7,
    );

    expect(p, {
      'cargo_type': 'food',
      'destination_id': 7,
      'pickup_address': 'Shop',
      'pickup_lat': 10.0,
      'pickup_lng': 106.0,
    });
  });

  test('a destination with a real delivery point keeps its coordinates', () {
    final p = buildPricingParams(
      cargoType: 'food',
      pickupLat: 10,
      pickupLng: 106,
      deliveryLat: 10.1,
      deliveryLng: 106.1,
      pickupAddress: 'Shop',
      deliveryAddress: 'Khách',
      destinationId: 7,
    );

    expect(p['delivery_lat'], 10.1);
    expect(p['destination_id'], 7);
    expect(p.containsKey('delivery_address'), isFalse);
  });
}
