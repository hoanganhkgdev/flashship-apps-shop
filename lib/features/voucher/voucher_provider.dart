import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voucher_model.dart';
import 'voucher_repository.dart';

final voucherProvider =
    AsyncNotifierProvider<VoucherNotifier, List<VoucherModel>>(
  VoucherNotifier.new,
);

class VoucherNotifier extends AsyncNotifier<List<VoucherModel>> {
  @override
  Future<List<VoucherModel>> build() => _fetch();

  Future<List<VoucherModel>> _fetch() async {
    return ref.read(voucherRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
