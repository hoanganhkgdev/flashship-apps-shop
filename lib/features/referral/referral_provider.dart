import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'referral_model.dart';
import 'referral_repository.dart';

final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo>(
    (ref) => ref.read(referralRepositoryProvider).fetchInfo());

final pointRewardsProvider = FutureProvider.autoDispose<List<PointRewardItem>>(
    (ref) => ref.read(referralRepositoryProvider).fetchRewards());
