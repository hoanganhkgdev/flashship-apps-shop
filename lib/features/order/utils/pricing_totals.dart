int feeBeforeNightSurcharge({
  required int totalFee,
  required int nightSurcharge,
}) =>
    (totalFee - nightSurcharge).clamp(0, totalFee);

int feeAfterDiscount({
  required int totalFee,
  int discount = 0,
}) =>
    (totalFee - discount).clamp(0, totalFee);
