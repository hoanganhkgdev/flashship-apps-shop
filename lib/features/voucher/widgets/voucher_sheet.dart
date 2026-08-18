import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../voucher_model.dart';
import '../voucher_provider.dart';
import 'voucher_card.dart';

/// Sheet chọn/nhập mã giảm giá dùng chung giữa màn tạo đơn đơn lẻ và đơn gộp.
/// Trả về `{code, discount, discount_label}` qua Navigator.pop khi áp thành
/// công, null nếu người dùng đóng sheet mà không áp mã nào.
class VoucherSheet extends ConsumerStatefulWidget {
  final int fee;

  const VoucherSheet({super.key, required this.fee});

  @override
  ConsumerState<VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<VoucherSheet> {
  final _codeCtrl = TextEditingController();
  bool _applying = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // Lý do không đủ điều kiện áp mã — null nếu voucher đủ điều kiện. Ưu tiên
  // theo thứ tự: hết hạn > hết lượt > chưa đạt đơn tối thiểu.
  String? _ineligibleReason(VoucherModel v) {
    if (v.isExpired) return 'Đã hết hạn sử dụng';
    if (v.isFull) return 'Đã hết lượt sử dụng';
    if (v.minOrderValue != null && widget.fee < v.minOrderValue!) {
      return 'Đơn tối thiểu ${Fmt.currency(v.minOrderValue!)}';
    }
    return null;
  }

  Future<void> _apply(String code) async {
    if (code.trim().isEmpty) return;
    setState(() { _applying = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).post('/shop/vouchers/validate', data: {
        'code':         code.trim(),
        'shipping_fee': widget.fee,
      });
      final data = res.data as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      final msg = parseApiError(e, fallback: 'Mã giảm giá không hợp lệ');
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vouchersAsync = ref.watch(voucherProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(children: [
              const Text('Mã giảm giá',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Nhập mã thủ công ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: AppField(
                    controller: _codeCtrl,
                    hint: 'Nhập mã giảm giá',
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _apply(_codeCtrl.text),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _applying ? null : () => _apply(_codeCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _applying
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Text('Áp dụng',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mã có thể áp dụng',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),

          // ── Danh sách mã ────────────────────────────────────────────
          Flexible(
            child: vouchersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Không có mã giảm giá khả dụng',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ),
                data: (vouchers) => vouchers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Không có mã giảm giá khả dụng',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: vouchers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final v = vouchers[i];
                          final reason = _ineligibleReason(v);
                          final eligible = reason == null;
                          return VoucherCard(
                            voucher: v,
                            eligible: eligible,
                            fadeContent: !eligible,
                            descriptionOverride: reason,
                            trailing: SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: (!eligible || _applying)
                                    ? null
                                    : () => _apply(v.code),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: eligible
                                      ? AppColors.primary
                                      : context.colors.surfaceAlt,
                                  disabledBackgroundColor: context.colors.surfaceAlt,
                                  foregroundColor:
                                      eligible ? Colors.white : AppColors.textSecondary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Áp dụng',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ),
        ],
      ),
    );
  }
}
