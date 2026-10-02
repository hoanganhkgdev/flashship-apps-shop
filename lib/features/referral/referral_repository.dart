import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'referral_model.dart';

final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => ApiReferralRepository(ref.read(apiClientProvider)),
);

abstract interface class ReferralRepository {
  Future<ReferralInfo> fetchInfo();
  Future<List<PointRewardItem>> fetchRewards();
  Future<RedeemResult> redeem(int rewardId);
}

class ApiReferralRepository implements ReferralRepository {
  final ApiClient _api;
  const ApiReferralRepository(this._api);

  @override
  Future<ReferralInfo> fetchInfo() async {
    final response = await _api.get('/shop/referral');
    return ReferralInfo.fromJson(
        (unwrap(response) as Map).cast<String, dynamic>());
  }

  @override
  Future<List<PointRewardItem>> fetchRewards() async {
    final response = await _api.get('/shop/referral/rewards');
    return (unwrap(response) as List<dynamic>)
        .map(
            (e) => PointRewardItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<RedeemResult> redeem(int rewardId) async {
    final response =
        await _api.post('/shop/referral/redeem', data: {'reward_id': rewardId});
    return RedeemResult.fromJson(
        (unwrap(response) as Map).cast<String, dynamic>());
  }
}
