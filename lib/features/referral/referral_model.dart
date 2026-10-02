/// Dữ liệu chương trình giới thiệu shop: mã, điểm, các lượt đã mời, lịch sử điểm.
class ReferralInfo {
  final String code;
  final int points;
  final ReferralProgram program;
  final int total;
  final int rewarded;
  final int pending;
  final List<ReferralEntry> referrals;
  final List<PointTransaction> transactions;

  const ReferralInfo({
    required this.code,
    required this.points,
    required this.program,
    required this.total,
    required this.rewarded,
    required this.pending,
    required this.referrals,
    required this.transactions,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReferralInfo(
      code: j['code'] as String? ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0,
      program: ReferralProgram.fromJson(
          (j['program'] as Map?)?.cast<String, dynamic>() ?? const {}),
      total: (stats['total'] as num?)?.toInt() ?? 0,
      rewarded: (stats['rewarded'] as num?)?.toInt() ?? 0,
      pending: (stats['pending'] as num?)?.toInt() ?? 0,
      referrals: ((j['referrals'] as List?) ?? const [])
          .map(
              (e) => ReferralEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      transactions: ((j['transactions'] as List?) ?? const [])
          .map((e) =>
              PointTransaction.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class ReferralProgram {
  final int pointsPerReferral;
  final int minOrders;
  final int welcomeAmount;

  const ReferralProgram({
    required this.pointsPerReferral,
    required this.minOrders,
    required this.welcomeAmount,
  });

  factory ReferralProgram.fromJson(Map<String, dynamic> j) => ReferralProgram(
        pointsPerReferral: (j['points_per_referral'] as num?)?.toInt() ?? 0,
        minOrders: (j['min_orders'] as num?)?.toInt() ?? 1,
        welcomeAmount: (j['welcome_amount'] as num?)?.toInt() ?? 0,
      );
}

class ReferralEntry {
  final int id;
  final String shopName;
  final String status; // pending | rewarded | rejected
  final int? points;
  final int requiredOrders;
  final DateTime? createdAt;

  const ReferralEntry({
    required this.id,
    required this.shopName,
    required this.status,
    required this.points,
    required this.requiredOrders,
    required this.createdAt,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> j) => ReferralEntry(
        id: (j['id'] as num).toInt(),
        shopName: j['shop_name'] as String? ?? 'Shop',
        status: j['status'] as String? ?? 'pending',
        points: (j['points'] as num?)?.toInt(),
        requiredOrders: (j['required_orders'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

class PointTransaction {
  final int id;
  final String type; // referral | redeem | adjust
  final int points;
  final int balanceAfter;
  final String description;
  final DateTime? createdAt;

  const PointTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> j) => PointTransaction(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String? ?? 'adjust',
        points: (j['points'] as num?)?.toInt() ?? 0,
        balanceAfter: (j['balance_after'] as num?)?.toInt() ?? 0,
        description: j['description'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

/// Một phần quà trong danh mục đổi điểm.
class PointRewardItem {
  final int id;
  final String name;
  final int pointsCost;
  final String type; // fixed | percent | freeship
  final int value;
  final int? minOrderValue;
  final int? maxDiscount;
  final int validDays;

  const PointRewardItem({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.type,
    required this.value,
    required this.minOrderValue,
    required this.maxDiscount,
    required this.validDays,
  });

  factory PointRewardItem.fromJson(Map<String, dynamic> j) => PointRewardItem(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        pointsCost: (j['points_cost'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? 'fixed',
        value: (j['value'] as num?)?.toInt() ?? 0,
        minOrderValue: (j['min_order_value'] as num?)?.toInt(),
        maxDiscount: (j['max_discount'] as num?)?.toInt(),
        validDays: (j['valid_days'] as num?)?.toInt() ?? 30,
      );
}

/// Kết quả đổi điểm: voucher vừa được cấp và số điểm còn lại.
class RedeemResult {
  final int balance;
  final String voucherCode;
  final String discountLabel;
  final DateTime? expiresAt;

  const RedeemResult({
    required this.balance,
    required this.voucherCode,
    required this.discountLabel,
    required this.expiresAt,
  });

  factory RedeemResult.fromJson(Map<String, dynamic> j) {
    final v = (j['voucher'] as Map).cast<String, dynamic>();
    return RedeemResult(
      balance: (j['balance'] as num?)?.toInt() ?? 0,
      voucherCode: v['code'] as String? ?? '',
      discountLabel: v['discount_label'] as String? ?? '',
      expiresAt: DateTime.tryParse(v['expires_at'] as String? ?? ''),
    );
  }
}
