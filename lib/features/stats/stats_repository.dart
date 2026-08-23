import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.read(apiClientProvider)),
);

class StatsRepository {
  final ApiClient _api;
  const StatsRepository(this._api);

  Future<Map<String, dynamic>> fetch({String? period}) async {
    final response = await _api.get('/shop/orders/stats',
        params: period == null ? null : {'period': period});
    return unwrap(response) as Map<String, dynamic>;
  }
}
