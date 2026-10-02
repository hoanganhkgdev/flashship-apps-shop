import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_decor_widgets.dart';
import '../../core/widgets/app_form_widgets.dart';
import '../voucher/voucher_provider.dart';
import 'referral_model.dart';
import 'referral_provider.dart';
import 'referral_repository.dart';

/// Giới thiệu & tích điểm: mã của shop, số điểm, cách hoạt động, đổi điểm lấy
/// voucher, các shop đã mời và lịch sử điểm.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  int? _redeemingId;

  Future<void> _refresh() async {
    ref.invalidate(referralInfoProvider);
    ref.invalidate(pointRewardsProvider);
    await ref.read(referralInfoProvider.future);
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success(context, message, duration: const Duration(seconds: 2));
  }

  Future<void> _redeem(PointRewardItem reward) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đổi voucher?',
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
        content: Text(
          'Dùng ${reward.pointsCost} điểm để đổi "${reward.name}". '
          'Voucher có hạn ${reward.validDays} ngày và chỉ dùng được một lần.',
          style: AppTextStyles.body.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đổi ngay')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _redeemingId = reward.id);
    try {
      final result =
          await ref.read(referralRepositoryProvider).redeem(reward.id);
      ref.invalidate(referralInfoProvider);
      ref.invalidate(voucherProvider);
      if (mounted) _showVoucher(result);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
            context, parseApiError(e, fallback: 'Không đổi được voucher'));
      }
    } finally {
      if (mounted) setState(() => _redeemingId = null);
    }
  }

  void _showVoucher(RedeemResult r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final c = ctx.colors;
        return AppSheet(
          icon: Icons.check_circle_rounded,
          color: c.success,
          title: 'Đổi voucher thành công',
          subtitle: 'Còn lại ${r.balance} điểm',
          footer: AppButton(
            label: 'Sao chép mã',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.voucherCode));
              Navigator.pop(ctx);
              AppSnackbar.success(context, 'Đã sao chép mã ${r.voucherCode}');
            },
          ),
          child: Column(children: [
            Text(r.discountLabel,
                style: AppTextStyles.metricLarge.copyWith(color: c.success)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.divider),
              ),
              child: Text(r.voucherCode,
                  style: AppTextStyles.metric
                      .copyWith(color: c.textPrimary, letterSpacing: 3)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              r.expiresAt == null
                  ? 'Dùng khi tạo đơn tiếp theo'
                  : 'Hạn dùng đến ${_date(r.expiresAt!)} · dùng khi tạo đơn',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
            ),
          ]),
        );
      },
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = ref.watch(referralInfoProvider);
    final rewards = ref.watch(pointRewardsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const AppPageHeader(
        title: 'Giới thiệu & tích điểm',
        subtitle: 'Mời shop bạn bè, nhận điểm đổi voucher',
      ),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: _refresh,
        child: info.when(
          loading: () => Center(
              child:
                  CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Center(
                  child: AppIconBadge(
                      icon: Icons.wifi_off_rounded,
                      color: c.textSecondary,
                      size: 64)),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text('Không tải được dữ liệu',
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: c.textPrimary)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: FilledButton.tonal(
                  onPressed: _refresh,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, AppSize.buttonHeight),
                    backgroundColor: c.primarySoft,
                    foregroundColor: c.primary,
                  ),
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ),
          data: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl4),
            children: [
              _PointsCard(info: data),
              const SizedBox(height: AppSpacing.md),
              _CodeCard(
                info: data,
                onCopyCode: () =>
                    _copy(data.code, 'Đã sao chép mã ${data.code}'),
                onCopyInvite: () => _copy(
                  'Đăng ký FlashShip để giao hàng nhanh như chớp! '
                      'Nhập mã giới thiệu ${data.code} khi đăng ký để nhận '
                      '${data.program.welcomeAmount > 0 ? 'voucher ${Fmt.currency(data.program.welcomeAmount)} ' : 'ưu đãi '}'
                      'sau khi hoàn thành ${data.program.minOrders} đơn đầu tiên.',
                  'Đã sao chép lời mời, dán gửi cho bạn bè',
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              _Title(Icons.lightbulb_rounded, 'Cách hoạt động'),
              _HowItWorks(program: data.program),
              const SizedBox(height: AppSpacing.xl2),
              _Title(Icons.redeem_rounded, 'Đổi điểm lấy voucher'),
              rewards.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => _Note('Không tải được danh mục đổi điểm'),
                data: (items) => items.isEmpty
                    ? _Note('Chưa có phần quà nào để đổi')
                    : Column(children: [
                        for (final item in items) ...[
                          _RewardTile(
                            reward: item,
                            points: data.points,
                            loading: _redeemingId == item.id,
                            onRedeem: () => _redeem(item),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Title(Icons.group_rounded, 'Shop đã mời (${data.total})'),
              data.referrals.isEmpty
                  ? _Note('Bạn chưa mời shop nào. Gửi mã của bạn để bắt đầu!')
                  : GlassCard(
                      blur: false,
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < data.referrals.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: c.divider),
                          _ReferralRow(entry: data.referrals[i]),
                        ],
                      ]),
                    ),
              if (data.transactions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl2),
                _Title(Icons.history_rounded, 'Lịch sử điểm'),
                GlassCard(
                  blur: false,
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < data.transactions.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.divider),
                      _TransactionRow(tx: data.transactions[i]),
                    ],
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Thành phần ───────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Title(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(children: [
        AppIconBadge(icon: icon, color: c.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => GlassCard(
        blur: false,
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: context.colors.textSecondary)),
      );
}

class _PointsCard extends StatelessWidget {
  final ReferralInfo info;
  const _PointsCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        glow: c.primary,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ĐIỂM CỦA BẠN',
                    style: AppTextStyles.caption
                        .copyWith(color: c.textTertiary, letterSpacing: .6)),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${info.points}',
                        style: AppTextStyles.metricLarge
                            .copyWith(color: c.primary)),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('điểm',
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: c.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    info.program.pointsPerReferral > 0
                        ? 'Mỗi shop mới hoạt động bạn nhận +${info.program.pointsPerReferral} điểm'
                        : 'Chương trình tích điểm đang tạm dừng',
                    style:
                        AppTextStyles.label.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          AppIconBadge(icon: Icons.stars_rounded, color: c.warning, size: 56),
        ]),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final ReferralInfo info;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyInvite;
  const _CodeCard({
    required this.info,
    required this.onCopyCode,
    required this.onCopyInvite,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        glow: c.accent2,
        child: Column(children: [
          Text('MÃ GIỚI THIỆU CỦA BẠN',
              style: AppTextStyles.caption
                  .copyWith(color: c.textTertiary, letterSpacing: .6)),
          const SizedBox(height: AppSpacing.sm),
          Text(info.code.isEmpty ? '—' : info.code,
              style: AppTextStyles.metricLarge
                  .copyWith(color: c.textPrimary, letterSpacing: 6)),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: info.code.isEmpty ? null : onCopyCode,
                icon: const Icon(Icons.copy_rounded, size: AppSize.iconMd),
                label: const Text('Sao chép mã'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: info.code.isEmpty ? null : onCopyInvite,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSize.buttonHeight)),
                icon: const Icon(Icons.send_rounded, size: AppSize.iconMd),
                label: const Text('Chép lời mời'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final ReferralProgram program;
  const _HowItWorks({required this.program});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final steps = [
      (
        Icons.share_rounded,
        'Chia sẻ mã của bạn',
        'Gửi mã cho chủ shop khác, họ nhập mã ở ô "Mã giới thiệu" khi đăng ký.'
      ),
      (
        Icons.local_shipping_rounded,
        'Shop mới hoạt động',
        'Khi shop đó hoàn thành ${program.minOrders} đơn, bạn nhận +${program.pointsPerReferral} điểm'
            '${program.welcomeAmount > 0 ? ' và shop mới nhận voucher ${Fmt.currency(program.welcomeAmount)}' : ''}.'
      ),
      (
        Icons.redeem_rounded,
        'Đổi điểm lấy voucher',
        'Dùng điểm tích luỹ để đổi voucher giảm phí giao hàng ở bên dưới.'
      ),
    ];
    return GlassCard(
      blur: false,
      child: Column(children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: glassIconDecoration(context, c.primary, circle: true),
              child: Text('${i + 1}',
                  style: AppTextStyles.label
                      .copyWith(color: c.primary, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(steps[i].$2,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(steps[i].$3,
                      style: AppTextStyles.label.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.4)),
                ],
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final PointRewardItem reward;
  final int points;
  final bool loading;
  final VoidCallback onRedeem;
  const _RewardTile({
    required this.reward,
    required this.points,
    required this.loading,
    required this.onRedeem,
  });

  String get _subtitle {
    final parts = <String>[
      if (reward.minOrderValue != null)
        'Phí ship từ ${Fmt.currency(reward.minOrderValue!)}',
      if (reward.maxDiscount != null)
        'Giảm tối đa ${Fmt.currency(reward.maxDiscount!)}',
      'Hạn ${reward.validDays} ngày',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enough = points >= reward.pointsCost;
    return GlassCard(
      blur: false,
      glow: enough ? c.success : null,
      child: Row(children: [
        AppIconBadge(
            icon: Icons.local_activity_rounded,
            color: enough ? c.success : c.textTertiary,
            size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reward.name,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(_subtitle,
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w500, color: c.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: FilledButton(
            onPressed: enough && !loading ? onRedeem : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('${reward.pointsCost} điểm'),
          ),
        ),
      ]),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final ReferralEntry entry;
  const _ReferralRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (entry.status) {
      'rewarded' => (
          entry.points != null ? '+${entry.points} điểm' : 'Đã cộng điểm',
          c.success
        ),
      'rejected' => ('Không hợp lệ', c.danger),
      _ => ('Chờ ${entry.requiredOrders} đơn', c.warning),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(children: [
        AppIconBadge(icon: Icons.storefront_rounded, color: color, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(entry.shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final PointTransaction tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plus = tx.points >= 0;
    final color = plus ? c.success : c.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(children: [
        AppIconBadge(
            icon: plus ? Icons.add_rounded : Icons.remove_rounded,
            color: color,
            size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              if (tx.createdAt != null)
                Text(_ReferralScreenState._date(tx.createdAt!),
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w500, color: c.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('${plus ? '+' : ''}${tx.points}',
            style: AppTextStyles.metric.copyWith(color: color)),
      ]),
    );
  }
}
