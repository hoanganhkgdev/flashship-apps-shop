import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';

class TodayStats {
  final int orders, active, revenue;
  const TodayStats({
    this.orders  = 0,
    this.active  = 0,
    this.revenue = 0,
  });

  // "active" lấy từ tổng toàn thời gian (data['active']), KHÔNG phải
  // data['today']['active'] — trước đây header trang chủ và mục "Đang
  // chạy" bên dưới lệch số nhau vì header chỉ đếm đơn tạo trong ngày, còn
  // đơn từ hôm trước vẫn đang giao thì bị bỏ sót. "Đang chạy" bản chất là
  // trạng thái hiện tại, không phải hoạt động trong ngày, nên dùng số thật
  // toàn thời gian cho cả 2 nơi.
  factory TodayStats.fromJson(Map<String, dynamic> data) {
    final today = data['today'] as Map<String, dynamic>? ?? {};
    return TodayStats(
      orders:  Fmt.toInt(today['orders']),
      active:  Fmt.toInt(data['active']),
      revenue: Fmt.toInt(today['revenue']),
    );
  }
}

final todayStatsProvider =
    FutureProvider.autoDispose<TodayStats>((ref) async {
  final res  = await ref.read(apiClientProvider).get('/shop/orders/stats');
  final data = unwrap(res) as Map<String, dynamic>;
  return TodayStats.fromJson(data);
});
