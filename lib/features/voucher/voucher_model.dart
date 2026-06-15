class VoucherModel {
  final int     id;
  final String  code;
  final String  type;
  final int     value;
  final String  discountLabel;
  final String? description;
  final int?    minOrderValue;
  final int?    maxDiscount;
  final int?    usageCount;
  final int?    usageLimit;
  final DateTime? expiresAt;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.discountLabel,
    this.description,
    this.minOrderValue,
    this.maxDiscount,
    this.usageCount,
    this.usageLimit,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isFull =>
      usageLimit != null && (usageCount ?? 0) >= usageLimit!;

  factory VoucherModel.fromJson(Map<String, dynamic> j) => VoucherModel(
        id:            j['id'] as int,
        code:          j['code'] as String,
        type:          j['type'] as String,
        value:         j['value'] as int,
        discountLabel: j['discount_label'] as String? ?? '',
        description:   j['description'] as String?,
        minOrderValue: j['min_order_value'] as int?,
        maxDiscount:   j['max_discount'] as int?,
        usageCount:    j['usage_count'] as int?,
        usageLimit:    j['usage_limit'] as int?,
        expiresAt: j['expires_at'] != null
            ? DateTime.tryParse(j['expires_at'] as String)
            : null,
      );
}
