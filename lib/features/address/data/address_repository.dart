import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/address_entry.dart';

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => ApiAddressRepository(ref.read(apiClientProvider)),
);

class AddressDraft {
  final String name;
  final String phone;
  final String address;
  final String? label;
  final double? lat;
  final double? lng;

  const AddressDraft({
    required this.name,
    required this.phone,
    required this.address,
    this.label,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson({bool includeEmptyLabel = false}) => {
        'name': name,
        'phone': phone,
        'address': address,
        if (includeEmptyLabel || label?.isNotEmpty == true)
          'label': label ?? '',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

abstract interface class AddressRepository {
  Future<List<AddressEntry>> fetchAll();
  Future<AddressEntry> add(AddressDraft draft);
  Future<void> update(int id, AddressDraft draft);
  Future<void> delete(int id);
}

class ApiAddressRepository implements AddressRepository {
  final ApiClient _api;
  const ApiAddressRepository(this._api);

  @override
  Future<List<AddressEntry>> fetchAll() async {
    final response = await _api.get('/shop/addresses');
    final data = unwrap(response) as List<dynamic>? ?? const [];
    return data
        .map((item) => AddressEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AddressEntry> add(AddressDraft draft) async {
    final response = await _api.post('/shop/addresses', data: draft.toJson());
    return AddressEntry.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  @override
  Future<void> update(int id, AddressDraft draft) async {
    await _api.patch('/shop/addresses/$id',
        data: draft.toJson(includeEmptyLabel: true));
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete('/shop/addresses/$id');
  }
}
