import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'voucher_model.dart';

final voucherProvider =
    AsyncNotifierProvider<VoucherNotifier, List<VoucherModel>>(
  VoucherNotifier.new,
);

class VoucherNotifier extends AsyncNotifier<List<VoucherModel>> {
  @override
  Future<List<VoucherModel>> build() => _fetch();

  Future<List<VoucherModel>> _fetch() async {
    final res = await ref.read(apiClientProvider).get('/shop/vouchers');
    final data = unwrap(res);
    return (data as List)
        .map((e) => VoucherModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
