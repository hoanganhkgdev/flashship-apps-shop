import 'package:flashship_shop/features/order/utils/pricing_totals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('night surcharge is shown as a component, not added twice', () {
    const apiTotal = 60000;
    const nightSurcharge = 5000;

    expect(
      feeBeforeNightSurcharge(
        totalFee: apiTotal,
        nightSurcharge: nightSurcharge,
      ),
      55000,
    );
    expect(feeAfterDiscount(totalFee: apiTotal), apiTotal);
  });

  test('discount is deducted once from the API total', () {
    expect(feeAfterDiscount(totalFee: 60000, discount: 10000), 50000);
    expect(feeAfterDiscount(totalFee: 60000, discount: 90000), 0);
  });
}
