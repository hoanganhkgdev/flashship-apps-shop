import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_widgets.dart';
import 'voucher_model.dart';
import 'voucher_provider.dart';
import 'widgets/voucher_card.dart';

class VoucherScreen extends ConsumerStatefulWidget {
  const VoucherScreen({super.key});

  @override
  ConsumerState<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends ConsumerState<VoucherScreen> {
  int _tab = 0;

  void _copy(BuildContext context, VoucherModel voucher) {
    Clipboard.setData(ClipboardData(text: voucher.code));
    AppSnackbar.success(
      context,
      'Đã sao chép mã ${voucher.code}',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(voucherProvider);
    final all = async.valueOrNull ?? const <VoucherModel>[];
    final usableCount = all.where((v) => !(v.isExpired || v.isFull)).length;
    final unavailableCount = all.length - usableCount;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        _VoucherHeader(
          selected: _tab,
          usableCount: usableCount,
          unavailableCount: unavailableCount,
          onSelected: (value) => setState(() => _tab = value),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: () => ref.read(voucherProvider.notifier).refresh(),
            child: async.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: c.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (_, __) => _VoucherMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Không tải được mã giảm giá',
                body: 'Kiểm tra kết nối rồi thử lại.',
                onRetry: () => ref.read(voucherProvider.notifier).refresh(),
              ),
              data: (all) {
                final vouchers = _tab == 0
                    ? all.where((v) => !(v.isExpired || v.isFull)).toList()
                    : all.where((v) => v.isExpired || v.isFull).toList();
                if (vouchers.isEmpty) {
                  return _VoucherMessage(
                    icon: Icons.confirmation_number_outlined,
                    title: _tab == 0
                        ? 'Chưa có mã khả dụng'
                        : 'Chưa có mã hết hạn',
                    body: _tab == 0
                        ? 'Ưu đãi mới dành cho cửa hàng sẽ xuất hiện tại đây.'
                        : 'Các mã hết hạn hoặc hết lượt sẽ xuất hiện tại đây.',
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final voucher = vouchers[index];
                    final eligible = _tab == 0;
                    return VoucherCard(
                      voucher: voucher,
                      eligible: eligible,
                      fadeContent: !eligible,
                      descriptionOverride: eligible
                          ? null
                          : voucher.isExpired
                              ? 'Đã hết hạn sử dụng'
                              : 'Đã hết lượt sử dụng',
                      onTap: eligible ? () => _copy(context, voucher) : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _VoucherHeader extends StatelessWidget {
  final int selected;
  final int usableCount;
  final int unavailableCount;
  final ValueChanged<int> onSelected;

  const _VoucherHeader({
    required this.selected,
    required this.usableCount,
    required this.unavailableCount,
    required this.onSelected,
  });

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            Row(children: [
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
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Mã '),
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
                      'Sao chép mã và chọn ưu đãi khi tạo đơn',
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
            const SizedBox(height: 12),
            Row(children: [
              _VoucherTab(
                label: 'Khả dụng',
                count: usableCount,
                selected: selected == 0,
                onTap: () => onSelected(0),
              ),
              const SizedBox(width: 8),
              _VoucherTab(
                label: 'Hết hạn',
                count: unavailableCount,
                selected: selected == 1,
                onTap: () => onSelected(1),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _VoucherTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _VoucherTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Material(
        color: selected ? c.primary : c.surface.withValues(alpha: .86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? c.primary : const Color(0xFFFFD1BF),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              minHeight: 42 +
                  (MediaQuery.textScalerOf(context).scale(12) - 12)
                      .clamp(0.0, double.infinity),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              '$label  $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoucherMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  const _VoucherMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        AppEmptyState(
          icon: icon,
          iconColor: c.primary,
          boxColor: c.primarySoft,
          title: title,
          titleColor: c.textPrimary,
          subtitle: body,
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
