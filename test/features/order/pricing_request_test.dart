import 'package:flashship_shop/features/order/utils/pricing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends coordinates when both points are resolved', () {
    final p = buildPricingParams(
      cargoType: 'food',
      pickupLat: 10,
      pickupLng: 106,
      deliveryLat: 10.1,
      deliveryLng: 106.1,
      pickupAddress: 'Shop',
      deliveryAddress: 'Khách',
    );

    expect(p['delivery_lat'], 10.1);
    expect(p.containsKey('delivery_address'), isFalse);
  });

  test('falls back to addresses without coordinates', () {
    final p = buildPricingParams(
      cargoType: 'food',
      pickupLat: null,
      pickupLng: null,
      deliveryLat: null,
      deliveryLng: null,
      pickupAddress: 'Shop',
      deliveryAddress: 'Khách',
    );

    expect(p, {
      'cargo_type': 'food',
      'pickup_address': 'Shop',
      'delivery_address': 'Khách',
    });
  });
}
