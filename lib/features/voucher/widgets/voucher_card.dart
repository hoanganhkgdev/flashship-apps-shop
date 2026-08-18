import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
    final c      = context.colors;
    final dimmed = !eligible;
    final accent = dimmed ? c.textTertiary : c.success;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Code
          Row(children: [
            Text(voucher.code,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: accent, letterSpacing: 0.5)),
            if (onTap != null) ...[
              const SizedBox(width: 5),
              Icon(Icons.copy_rounded, size: 12, color: accent),
            ],
          ]),
          const SizedBox(height: 4),
          // Mô tả / lý do không đủ điều kiện
          Text(
            descriptionOverride ??
                (voucher.description?.isNotEmpty == true
                    ? voucher.description!
                    : voucher.minOrderValue != null
                        ? 'Đơn từ ${voucher.minOrderValue}đ'
                        : 'Không giới hạn đơn tối thiểu'),
            style: TextStyle(fontSize: 10, color: c.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          // HSD + usage
          Row(children: [
            if (voucher.expiresAt != null) ...[
              Icon(Icons.access_time_rounded,
                  size: 10,
                  color: voucher.isExpired ? c.danger : c.textTertiary),
              const SizedBox(width: 3),
              Text(
                voucher.isExpired ? 'Hết hạn' : expiryText(voucher),
                style: TextStyle(
                    fontSize: 10,
                    color: voucher.isExpired ? c.danger : c.textTertiary),
              ),
            ],
            if (voucher.usageLimit != null) ...[
              const Spacer(),
              Text(
                '${voucher.usageCount ?? 0}/${voucher.usageLimit}',
                style: TextStyle(fontSize: 10, color: c.textTertiary),
              ),
            ],
          ]),
        ],
      ),
    );
    if (fadeContent) content = Opacity(opacity: 0.5, child: content);

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: c.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // IntrinsicHeight: Row(crossAxisAlignment: stretch) cần chiều cao xác
      // định để dải trái giãn đủ cao — an toàn cả khi widget này nằm trong
      // danh sách dọc (chiều cao item không giới hạn theo mặc định).
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Dải trái ──
          Container(
            width: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dimmed
                    ? [c.surfaceAlt, c.surfaceAlt]
                    : [c.success, c.success.withValues(alpha: 0.75)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(discountText(voucher),
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: dimmed ? c.textTertiary : Colors.white,
                        height: 1)),
                const SizedBox(height: 2),
                Text('OFF',
                    style: TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: dimmed
                            ? c.textTertiary
                            : Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),

          // ── Nội dung ──
          Expanded(child: content),

          // ── Hành động (vd nút Áp dụng) — luôn hiện rõ, không bị làm mờ ──
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(child: trailing),
            ),
        ]),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
