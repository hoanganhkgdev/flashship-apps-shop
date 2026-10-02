import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final cityRepositoryProvider = Provider<CityRepository>(
  (ref) => ApiCityRepository(ref.read(apiClientProvider)),
);

class CityItem {
  final int id;
  final String name;
  final double? lat;
  final double? lng;

  const CityItem({required this.id, required this.name, this.lat, this.lng});

  // Backend serialize cột decimal ra JSON dạng chuỗi (vd "10.0125000") nên
  // phải parse qua String thay vì ép kiểu num.
  static double? _coord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory CityItem.fromJson(Map<String, dynamic> json) => CityItem(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        lat: _coord(json['lat']),
        lng: _coord(json['lng']),
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
