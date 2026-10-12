import '../models/shop_order_type.dart';

class CreateOrderValidator {
  const CreateOrderValidator._();

  static String? locations({
    required String? pickupAddress,
    required String? deliveryAddress,
    required double? pickupLat,
    required double? pickupLng,
    required double? deliveryLat,
    required double? deliveryLng,
    // Đã chọn khu vực giao: địa chỉ/toạ độ điểm giao không bắt buộc (hệ thống
    // dùng tâm khu vực), nhưng điểm lấy vẫn cần.
    bool hasDestination = false,
  }) {
    if (pickupAddress == null || (deliveryAddress == null && !hasDestination)) {
      return hasDestination
          ? 'Vui lòng chọn điểm lấy hàng'
          : 'Vui lòng chọn điểm lấy và điểm giao';
    }
    if (pickupLat == null || pickupLng == null) {
      return 'Đang xác định toạ độ, vui lòng đợi vài giây rồi thử lại.';
    }
    // Có địa chỉ giao thì vẫn cần toạ độ của nó, trừ khi dùng khu vực.
    if (!hasDestination && (deliveryLat == null || deliveryLng == null)) {
      return 'Đang xác định toạ độ, vui lòng đợi vài giây rồi thử lại.';
    }
    return null;
  }

  static String? contacts({
    required ShopOrderType orderType,
    required String receiverPhone,
    required String senderPhone,
  }) {
    // Đơn giao: SĐT người nhận không bắt buộc (tài xế có thể xin shop sau).
    // Đơn lấy: đây là SĐT cửa hàng nhận hàng nên vẫn cần.
    if (orderType == ShopOrderType.pickup && receiverPhone.trim().isEmpty) {
      return 'Vui lòng nhập SĐT cửa hàng';
    }
    if (orderType == ShopOrderType.pickup && senderPhone.trim().isEmpty) {
      return 'Vui lòng nhập SĐT liên hệ tại điểm lấy';
    }
    return null;
  }
}
