import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'voucher_model.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>(
  (ref) => ApiVoucherRepository(ref.read(apiClientProvider)),
);

abstract interface class VoucherRepository {
  Future<List<VoucherModel>> fetchAll();
  Future<Map<String, dynamic>> validate(String code, int shippingFee);
}

class ApiVoucherRepository implements VoucherRepository {
  final ApiClient _api;
  const ApiVoucherRepository(this._api);

  @override
  Future<List<VoucherModel>> fetchAll() async {
    final response = await _api.get('/shop/vouchers');
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((item) => VoucherModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> validate(String code, int shippingFee) async {
    final response = await _api.post('/shop/vouchers/validate', data: {
      'code': code.trim(),
      'shipping_fee': shippingFee,
    });
    return response.data as Map<String, dynamic>;
  }
}
