import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

class CityItem {
  final int id;
  final String name;
  const CityItem({required this.id, required this.name});

  factory CityItem.fromJson(Map<String, dynamic> j) =>
      CityItem(id: j['id'] as int, name: j['name'] as String? ?? '');
}

final citiesProvider = FutureProvider<List<CityItem>>((ref) async {
  final res  = await Dio().get('${AppConstants.baseUrl}/cities');
  final list = (res.data['data'] ?? res.data) as List;
  return list.cast<Map<String, dynamic>>().map(CityItem.fromJson).toList();
});
