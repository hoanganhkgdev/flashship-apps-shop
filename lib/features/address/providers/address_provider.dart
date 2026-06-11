import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/address_entry.dart';

final addressProvider =
    StateNotifierProvider<AddressNotifier, AsyncValue<List<AddressEntry>>>(
        (ref) => AddressNotifier(ref));

class AddressNotifier extends StateNotifier<AsyncValue<List<AddressEntry>>> {
  final Ref _ref;

  AddressNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final res   = await _ref.read(apiClientProvider).get('/shop/addresses');
      final items = (res.data['data'] as List)
          .map((e) => AddressEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<AddressEntry?> add({
    required String name,
    required String phone,
    required String address,
    String? label,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _ref.read(apiClientProvider).post('/shop/addresses', data: {
        'name':    name,
        'phone':   phone,
        'address': address,
        if (label != null && label.isNotEmpty) 'label': label,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });
      final entry = AddressEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      state = state.whenData((list) => [entry, ...list]);
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<bool> update(int id, {
    required String name,
    required String phone,
    required String address,
    String? label,
    double? lat,
    double? lng,
  }) async {
    try {
      await _ref.read(apiClientProvider).patch('/shop/addresses/$id', data: {
        'name':    name,
        'phone':   phone,
        'address': address,
        'label':   label ?? '',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });
      state = state.whenData((list) => list.map((e) => e.id == id
          ? AddressEntry(id: id, label: label, name: name, phone: phone,
              address: address, lat: lat, lng: lng)
          : e).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _ref.read(apiClientProvider).delete('/shop/addresses/$id');
      state = state.whenData((list) => list.where((e) => e.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}
