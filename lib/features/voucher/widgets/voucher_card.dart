import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../voucher_model.dart';

/// Layout thẻ voucher dùng chung — dải trái tô success/discount lớn + "OFF",
/// phần phải hiện code/mô tả/hạn dùng. Dùng cho carousel ở trang chủ (tap
/// toàn thẻ để copy mã, [onTap]) và danh sách trong sheet chọn mã ở màn tạo
/// đơn (nút hành động riêng qua [trailing], không tap-copy).
class VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final bool eligible;
  final String? descriptionOverride;
  final VoidCallback? onTap;
  final Widget? trailing;
  // Làm mờ phần nội dung (không gồm dải trái/trailing) khi không đủ điều
  // kiện — mặc định false để không đổi giao diện carousel trang chủ hiện có
  // (nơi trạng thái hết hạn chỉ đổi màu, không làm mờ).
  final bool fadeContent;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.eligible = true,
    this.descriptionOverride,
    this.onTap,
    this.trailing,
    this.fadeContent = false,
  });

  static String discountText(VoucherModel v) =>
      v.type == 'percent' ? '-${v.value}%' : '-${v.value}đ';

  static String expiryText(VoucherModel v) {
    if (v.expiresAt == null) return '';
    final d = v.expiresAt!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dimmed = !eligible;
    final accent = dimmed ? c.textTertiary : c.primary;
    final description = descriptionOverride ??
        (voucher.description?.trim().isNotEmpty == true
            ? voucher.description!.trim()
            : 'Ưu đãi phí giao hàng dành cho cửa hàng');
    final conditions = [
      if (voucher.minOrderValue != null)
        'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}',
      if (voucher.maxDiscount != null)
        'Giảm tối đa ${Fmt.currency(voucher.maxDiscount!)}',
    ].join(' · ');

    Widget body = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              voucher.type == 'percent'
                  ? Icons.percent_rounded
                  : Icons.confirmation_number_outlined,
              size: 21,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucher.discountLabel.isNotEmpty
                      ? voucher.discountLabel
                      : discountText(voucher),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ]),
        if (conditions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            conditions,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 3, 4, 3),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                voucher.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                ),
              ),
            ),
            if (onTap != null)
              IconButton(
                tooltip: 'Sao chép mã',
                onPressed: onTap,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(40),
                  foregroundColor: accent,
                  backgroundColor: accent.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 9),
        Row(children: [
          Icon(
            Icons.schedule_rounded,
            size: 14,
            color: voucher.isExpired ? c.danger : c.textTertiary,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              voucher.expiresAt == null
                  ? 'Không giới hạn thời gian'
                  : voucher.isExpired
                      ? 'Đã hết hạn'
                      : 'HSD: ${expiryText(voucher)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: voucher.isExpired ? c.danger : c.textSecondary,
              ),
            ),
          ),
          if (voucher.usageLimit != null) ...[
            const SizedBox(width: 8),
            Text(
              '${voucher.usageCount ?? 0}/${voucher.usageLimit} lượt',
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ]),
      ]),
    );
    if (fadeContent) body = Opacity(opacity: .58, child: body);

    final card = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              child: body,
            ),
    );
    return card;
  }
}
