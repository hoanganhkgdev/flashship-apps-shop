import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../voucher_model.dart';
import '../voucher_provider.dart';
import '../voucher_repository.dart';
import 'voucher_card.dart';

/// Màn hình chọn/nhập mã giảm giá dùng chung giữa đơn đơn lẻ và đơn gộp.
/// Trả về `{code, discount, discount_label}` qua Navigator.pop khi áp thành
/// công, null nếu người dùng quay lại mà không áp mã nào.
class VoucherPickerScreen extends ConsumerStatefulWidget {
  final int fee;

  const VoucherPickerScreen({super.key, required this.fee});

  @override
  ConsumerState<VoucherPickerScreen> createState() =>
      _VoucherPickerScreenState();
}

class _VoucherPickerScreenState extends ConsumerState<VoucherPickerScreen> {
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
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(voucherRepositoryProvider).validate(code, widget.fee);
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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          const _VoucherPickerHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _OrderFeeCard(fee: widget.fee),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.divider),
              ),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
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
                  width: 96,
                  height: 46,
                  child: FilledButton(
                    onPressed: _applying ? null : () => _apply(_codeCtrl.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                      disabledBackgroundColor: c.primary.withValues(alpha: .45),
                      disabledForegroundColor: c.onPrimary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Áp dụng',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: _VoucherSectionTitle(),
          ),
          Expanded(
            child: vouchersAsync.when(
              loading: () => const _VoucherLoading(),
              error: (_, __) => _VoucherMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Không tải được mã giảm giá',
                subtitle: 'Kiểm tra kết nối rồi thử lại.',
                onRetry: () => ref.read(voucherProvider.notifier).refresh(),
              ),
              data: (vouchers) => vouchers.isEmpty
                  ? const _VoucherMessage(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Chưa có mã giảm giá',
                      subtitle:
                          'Ưu đãi mới dành cho cửa hàng sẽ xuất hiện tại đây.',
                    )
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: () =>
                          ref.read(voucherProvider.notifier).refresh(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: vouchers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final voucher = vouchers[i];
                          final reason = _ineligibleReason(voucher);
                          final eligible = reason == null;
                          return VoucherCard(
                            voucher: voucher,
                            eligible: eligible,
                            fadeContent: !eligible,
                            descriptionOverride: reason,
                            trailing: SizedBox(
                              height: 34,
                              child: FilledButton(
                                onPressed: (!eligible || _applying)
                                    ? null
                                    : () => _apply(voucher.code),
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: c.onPrimary,
                                  disabledBackgroundColor: c.surfaceAlt,
                                  disabledForegroundColor: c.textSecondary,
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Chọn',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherPickerHeader extends StatelessWidget {
  const _VoucherPickerHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(44),
                backgroundColor: c.surface,
                side: BorderSide(color: c.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: c.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Chọn mã '),
                      TextSpan(
                        text: 'giảm giá',
                        style: TextStyle(color: c.primary),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Chọn ưu đãi phù hợp cho đơn hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OrderFeeCard extends StatelessWidget {
  final int fee;

  const _OrderFeeCard({required this.fee});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.primary.withValues(alpha: .20)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long_outlined, size: 21, color: c.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phí giao hàng hiện tại',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                  )),
              const SizedBox(height: 2),
              Text(
                Fmt.currency(fee),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.local_offer_outlined, size: 20, color: c.primary),
      ]),
    );
  }
}

class _VoucherSectionTitle extends StatelessWidget {
  const _VoucherSectionTitle();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ưu đãi dành cho bạn',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Mã không đủ điều kiện vẫn được hiển thị',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoucherLoading extends StatelessWidget {
  const _VoucherLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 176,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: c.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _VoucherMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _VoucherMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      children: [
        AppEmptyState(
          icon: icon,
          title: title,
          subtitle: subtitle,
          iconColor: c.primary,
          boxColor: c.primarySoft,
          titleColor: c.textPrimary,
          action: onRetry == null
              ? null
              : TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
        ),
      ],
    );
  }
}
