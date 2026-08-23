import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final cityRepositoryProvider = Provider<CityRepository>(
  (ref) => ApiCityRepository(ref.read(apiClientProvider)),
);

class CityItem {
  final int id;
  final String name;

  const CityItem({required this.id, required this.name});

  factory CityItem.fromJson(Map<String, dynamic> json) => CityItem(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}

abstract interface class CityRepository {
  Future<List<CityItem>> fetchAll();
}

class ApiCityRepository implements CityRepository {
  final ApiClient _api;

  const ApiCityRepository(this._api);

  @override
  Future<List<CityItem>> fetchAll() async {
    final response = await _api.get('/cities');
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((item) => CityItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
