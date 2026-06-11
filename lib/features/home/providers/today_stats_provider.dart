import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class TodayStats {
  final int orders, active, revenue;
  const TodayStats({
    this.orders  = 0,
    this.active  = 0,
    this.revenue = 0,
  });

  factory TodayStats.fromJson(Map<String, dynamic> j) => TodayStats(
    orders:  _n(j['orders']),
    active:  _n(j['active']),
    revenue: _n(j['revenue']),
  );
}

int _n(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0;

final todayStatsProvider =
    FutureProvider.autoDispose<TodayStats>((ref) async {
  final res  = await ref.read(apiClientProvider).get('/shop/orders/stats');
  final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
  final today = data['today'] as Map<String, dynamic>? ?? {};
  return TodayStats.fromJson(today);
});
