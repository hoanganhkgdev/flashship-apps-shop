class BatchStopValidationInput {
  final String address;
  final String phone;
  final double? lat;
  final double? lng;

  /// Đã chọn khu vực giao: địa chỉ/toạ độ của điểm không bắt buộc.
  final bool hasDestination;

  const BatchStopValidationInput({
    required this.address,
    required this.phone,
    this.lat,
    this.lng,
    this.hasDestination = false,
  });
}

class CreateBatchOrderValidator {
  const CreateBatchOrderValidator._();

  static String? validate({
    required String pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required List<BatchStopValidationInput> stops,
    // Thành phố có khu vực giao để chọn (chỉ để thông báo cho đúng).
    bool areasAvailable = false,
  }) {
    if (pickupAddress.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ cửa hàng';
    }
    if (pickupLat == null || pickupLng == null) {
      return 'Vui lòng chọn địa chỉ cửa hàng từ gợi ý hoặc bản đồ';
    }
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final n = index + 1;
      // Điểm giao cần địa chỉ (có toạ độ) hoặc khu vực giao.
      if (!stop.hasDestination) {
        if (stop.address.trim().isEmpty) {
          return areasAvailable
              ? 'Điểm $n: cần nhập địa chỉ hoặc chọn khu vực giao'
              : 'Điểm $n: cần nhập địa chỉ';
        }
        if (stop.lat == null || stop.lng == null) {
          return 'Điểm $n: vui lòng chọn địa chỉ từ gợi ý hoặc bản đồ';
        }
      }
      if (stop.phone.trim().isEmpty) {
        return 'Điểm $n: cần nhập SĐT người nhận';
      }
    }
    return null;
  }
}
