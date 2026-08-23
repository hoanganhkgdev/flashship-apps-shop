import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/city_repository.dart';

export '../data/city_repository.dart' show CityItem;

final citiesProvider = FutureProvider<List<CityItem>>((ref) async {
  return ref.read(cityRepositoryProvider).fetchAll();
});
