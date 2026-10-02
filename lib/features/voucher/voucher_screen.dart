import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_decor_widgets.dart';
import '../../core/widgets/app_form_widgets.dart';
import 'voucher_model.dart';
import 'voucher_provider.dart';
import 'widgets/voucher_card.dart';

/// Trang danh sách mã giảm giá của cửa hàng: mã còn dùng được ở trên, mã hết
/// hạn / hết lượt ở dưới. Chạm vào thẻ để sao chép mã.
class VoucherScreen extends ConsumerWidget {
  const VoucherScreen({super.key});

  void _copy(BuildContext context, VoucherModel v) {
    Clipboard.setData(ClipboardData(text: v.code));
    AppSnackbar.success(context, 'Đã sao chép mã ${v.code}',
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(voucherProvider);

    Widget message(IconData icon, String title, String body,
            {VoidCallback? onRetry}) =>
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
                child:
                    AppIconBadge(icon: icon, color: c.textSecondary, size: 64)),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(title,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
              child: Text(body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: FilledButton.tonal(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, AppSize.buttonHeight),
                    backgroundColor: c.primarySoft,
                    foregroundColor: c.primary,
                  ),
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ],
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const AppPageHeader(
        title: 'Mã giảm giá',
        subtitle: 'Ưu đãi phí giao hàng cho cửa hàng',
      ),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: () => ref.read(voucherProvider.notifier).refresh(),
        child: async.when(
          loading: () => Center(
              child:
                  CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
          error: (_, __) => message(
            Icons.wifi_off_rounded,
            'Không tải được mã giảm giá',
            'Kiểm tra kết nối rồi thử lại',
            onRetry: () => ref.read(voucherProvider.notifier).refresh(),
          ),
          data: (vouchers) {
            if (vouchers.isEmpty) {
              return message(
                Icons.local_activity_outlined,
                'Chưa có mã giảm giá',
                'Các ưu đãi mới sẽ xuất hiện ở đây. Mã sẽ được áp dụng khi bạn đặt đơn.',
              );
            }
            final usable =
                vouchers.where((v) => !(v.isExpired || v.isFull)).toList();
            final unusable =
                vouchers.where((v) => v.isExpired || v.isFull).toList();

            Widget section(String title, List<VoucherModel> items,
                    {required bool eligible}) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('$title (${items.length})',
                        style: AppTextStyles.sectionTitle
                            .copyWith(color: c.textPrimary)),
                  ),
                  for (final v in items) ...[
                    VoucherCard(
                      voucher: v,
                      eligible: eligible,
                      fadeContent: !eligible,
                      descriptionOverride: eligible
                          ? null
                          : (v.isExpired
                              ? 'Đã hết hạn sử dụng'
                              : 'Đã hết lượt sử dụng'),
                      onTap: eligible ? () => _copy(context, v) : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ]);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl4),
              children: [
                if (usable.isNotEmpty)
                  section('Có thể sử dụng', usable, eligible: true),
                if (usable.isNotEmpty && unusable.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
                if (unusable.isNotEmpty)
                  section('Hết hạn / hết lượt', unusable, eligible: false),
              ],
            );
          },
        ),
      ),
    );
  }
}
