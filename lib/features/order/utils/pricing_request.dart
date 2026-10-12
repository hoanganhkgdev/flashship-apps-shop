/// Tham số chung gửi lên `/shop/pricing/estimate`. Không bao gồm các field
/// riêng theo màn hình (vd. `night_surcharge` chỉ được đọc từ response ở
/// màn tạo đơn đơn lẻ, không áp dụng cho từng điểm giao trong đơn gộp).
Map<String, dynamic> buildPricingParams({
  required String cargoType,
  double? cargoWeight,
  required double? pickupLat,
  required double? pickupLng,
  required double? deliveryLat,
  required double? deliveryLng,
  required String pickupAddress,
  required String deliveryAddress,
  int? destinationId,
}) {
  final p = <String, dynamic>{'cargo_type': cargoType};
  if (cargoWeight != null) p['cargo_weight'] = cargoWeight;
  if (destinationId != null) p['destination_id'] = destinationId;
  if (destinationId != null && deliveryLat == null && deliveryAddress.isEmpty) {
    // Chỉ chọn khu vực: server dùng tâm khu vực làm điểm giao.
    p['pickup_address'] = pickupAddress;
    if (pickupLat != null && pickupLng != null) {
      p['pickup_lat'] = pickupLat;
      p['pickup_lng'] = pickupLng;
    }
  } else if (pickupLat != null && deliveryLat != null) {
    p['pickup_lat'] = pickupLat;
    p['pickup_lng'] = pickupLng;
    p['delivery_lat'] = deliveryLat;
    p['delivery_lng'] = deliveryLng;
  } else {
    p['pickup_address'] = pickupAddress;
    p['delivery_address'] = deliveryAddress;
  }
  return p;
}
