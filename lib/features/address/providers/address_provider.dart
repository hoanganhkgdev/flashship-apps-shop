import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/address_repository.dart';
import '../models/address_entry.dart';

final addressProvider =
    StateNotifierProvider<AddressNotifier, AsyncValue<List<AddressEntry>>>(
        (ref) => AddressNotifier(ref.read(addressRepositoryProvider)));

class AddressNotifier extends StateNotifier<AsyncValue<List<AddressEntry>>> {
  final AddressRepository _repository;

  AddressNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.fetchAll();
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
      final entry = await _repository.add(AddressDraft(
        name: name,
        phone: phone,
        address: address,
        label: label,
        lat: lat,
        lng: lng,
      ));
      state = state.whenData((list) => [entry, ...list]);
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<bool> update(
    int id, {
    required String name,
    required String phone,
    required String address,
    String? label,
    double? lat,
    double? lng,
  }) async {
    try {
      await _repository.update(
          id,
          AddressDraft(
            name: name,
            phone: phone,
            address: address,
            label: label,
            lat: lat,
            lng: lng,
          ));
      state = state.whenData((list) => list
          .map((e) => e.id == id
              ? AddressEntry(
                  id: id,
                  label: label,
                  name: name,
                  phone: phone,
                  address: address,
                  lat: lat,
                  lng: lng)
              : e)
          .toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      state = state.whenData((list) => list.where((e) => e.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}
