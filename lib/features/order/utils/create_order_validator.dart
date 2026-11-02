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
  }) {
    if (pickupAddress == null) return 'Vui lòng chọn điểm lấy hàng';
    if (deliveryAddress == null) return 'Vui lòng chọn điểm giao';
    if (pickupLat == null || pickupLng == null) {
      return 'Đang xác định toạ độ, vui lòng đợi vài giây rồi thử lại.';
    }
    if (deliveryLat == null || deliveryLng == null) {
      return 'Đang xác định toạ độ, vui lòng đợi vài giây rồi thử lại.';
    }
    return null;
  }

  static String? contacts({
    required ShopOrderType orderType,
    required String receiverPhone,
    required String senderPhone,
  }) {
    // Đơn giao: SĐT người nhận. Đơn lấy: SĐT cửa hàng nhận hàng.
    if (receiverPhone.trim().isEmpty) {
      return orderType == ShopOrderType.delivery
          ? 'Vui lòng nhập SĐT người nhận'
          : 'Vui lòng nhập SĐT cửa hàng';
    }
    if (orderType == ShopOrderType.pickup && senderPhone.trim().isEmpty) {
      return 'Vui lòng nhập SĐT liên hệ tại điểm lấy';
    }
    return null;
  }
}
