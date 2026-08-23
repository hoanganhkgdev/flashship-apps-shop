import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/support_config_item.dart';

final supportConfigRepositoryProvider = Provider<SupportConfigRepository>(
  (ref) => SupportConfigRepository(ref.read(apiClientProvider)),
);

class SupportConfigRepository {
  final ApiClient _api;
  const SupportConfigRepository(this._api);

  Future<List<SupportConfigItem>> fetchAll() async {
    final response = await _api.get('/support-configs');
    final data = unwrap(response) as List<dynamic>? ?? const [];
    return data
        .map((item) => SupportConfigItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
