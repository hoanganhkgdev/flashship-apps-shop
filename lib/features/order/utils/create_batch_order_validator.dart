class BatchStopValidationInput {
  final String address;
  final String phone;
  final double? lat;
  final double? lng;

  const BatchStopValidationInput({
    required this.address,
    required this.phone,
    this.lat,
    this.lng,
  });
}

class CreateBatchOrderValidator {
  const CreateBatchOrderValidator._();

  static String? validate({
    required String pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required List<BatchStopValidationInput> stops,
  }) {
    if (pickupAddress.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ cửa hàng';
    }
    if (pickupLat == null || pickupLng == null) {
      return 'Vui lòng chọn địa chỉ cửa hàng từ gợi ý hoặc bản đồ';
    }
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      if (stop.address.trim().isEmpty || stop.phone.trim().isEmpty) {
        return 'Điểm ${index + 1}: cần nhập địa chỉ và SĐT';
      }
      if (stop.lat == null || stop.lng == null) {
        return 'Điểm ${index + 1}: vui lòng chọn địa chỉ từ gợi ý hoặc bản đồ';
      }
    }
    return null;
  }
}
