import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../models/order_model.dart';

/// Dữ liệu điền sẵn cho CreateOrderScreen từ một đơn cũ.
Map<String, dynamic> reorderExtra(OrderModel o) {
  final isOutbound = o.shopServiceType != 'shop_pickup';
  return {
    'isOutbound': isOutbound,
    'pickupAddr': o.pickupAddress,
    'pickupLat': o.pickupLat,
    'pickupLng': o.pickupLng,
    'pickupPhone': o.pickupPhone,
    'pickupName': o.senderName,
    'deliveryAddr': o.deliveryAddress,
    'deliveryLat': o.deliveryLat,
    'deliveryLng': o.deliveryLng,
    'deliveryPhone': o.deliveryPhone,
    'deliveryName': o.receiverName,
    'cargoType': o.cargoType,
    'note': o.orderNote,
  };
}

/// Dữ liệu điền sẵn cho CreateBatchOrderScreen từ một đơn gộp cũ — SĐT lấy
/// hàng không đưa vào đây, CreateBatchOrderScreen tự điền lại từ hồ sơ shop
/// giống luồng tạo đơn mới (batch luôn lấy tại chính shop).
Map<String, dynamic> reorderBatchExtra(OrderModel o) {
  return {
    'pickupAddr': o.pickupAddress,
    'pickupLat': o.pickupLat,
    'pickupLng': o.pickupLng,
    'cargoType': o.cargoType,
    'stops': o.stops
        .map((s) => {
              'address': s['address'] as String? ?? '',
              'lat': (s['lat'] as num?)?.toDouble(),
              'lng': (s['lng'] as num?)?.toDouble(),
              'phone': s['phone'] as String? ?? '',
              'name': s['name'] as String? ?? '',
              'codAmount': (s['cod_amount'] as num?)?.toInt(),
              'note': s['note'] as String? ?? '',
            })
        .toList(),
  };
}

/// Mở màn tạo đơn với thông tin lấy từ [order] — dùng chung cho chi tiết đơn,
/// danh sách đơn và mục "Đặt lại nhanh" ở trang chủ.
void reorderOrder(BuildContext context, OrderModel order) {
  if (order.isBatch) {
    context.push('/create-batch', extra: reorderBatchExtra(order));
  } else {
    context.push('/create-order', extra: reorderExtra(order));
  }
}
