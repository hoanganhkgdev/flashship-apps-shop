import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../data/city_repository.dart';

export '../data/city_repository.dart' show CityItem;

final citiesProvider = FutureProvider<List<CityItem>>((ref) async {
  return ref.read(cityRepositoryProvider).fetchAll();
});

/// Toạ độ trung tâm của khu vực: ưu tiên lat/lng từ server (khớp theo id, rồi
/// theo tên), fallback bảng [kCityCenters] cho khu vực chưa có toạ độ.
({double lat, double lng})? cityCenter(
  List<CityItem> cities, {
  int? cityId,
  String? cityName,
}) {
  CityItem? city;
  for (final c in cities) {
    if (cityId != null && c.id == cityId) {
      city = c;
      break;
    }
  }
  if (city == null && cityName != null) {
    for (final c in cities) {
      if (c.name == cityName) {
        city = c;
        break;
      }
    }
  }
  if (city?.lat != null && city?.lng != null) {
    return (lat: city!.lat!, lng: city.lng!);
  }
  return kCityCenters[city?.name ?? cityName];
}
