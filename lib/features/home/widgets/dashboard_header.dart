part of '../screens/home_screen.dart';

/// Bề mặt đặc dùng riêng trên trang chủ, không lọc nền khi cuộn.
class _HomeSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HomeSurface({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      );
}

/// Header trang chủ đồng bộ cấu trúc phẳng, ấm của app customer.
class _Header extends ConsumerWidget {
  final String shopName;
  final String shopAddress;

  const _Header({required this.shopName, required this.shopAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HomeHeaderDelegate(
        topInset: MediaQuery.paddingOf(context).top,
        textScale:
            MediaQuery.textScalerOf(context).scale(16).clamp(16, 22) / 16,
        shopName: shopName.trim(),
        shopAddress: shopAddress.trim(),
        unread: unread,
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topInset;
  final double textScale;
  final String shopName;
  final String shopAddress;
  final int unread;

  const _HomeHeaderDelegate({
    required this.topInset,
    required this.textScale,
    required this.shopName,
    required this.shopAddress,
    required this.unread,
  });

  static const _addressRow = 56.0;
  static const _greetingRow = 48.0;
  static const _gap = 10.0;

  @override
  double get minExtent => topInset + _gap * 2 + _addressRow * textScale;

  @override
  double get maxExtent => minExtent + (_greetingRow + _gap) * textScale;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return SizedBox.expand(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DE),
            border: Border(
              bottom: BorderSide(
                color: Color.lerp(
                  const Color(0xFFFFE9DE),
                  const Color(0xFFFFD7C7),
                  progress,
                )!,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - progress,
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10 * textScale),
                      child: SizedBox(
                        height: 48 * textScale,
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Xin chào,',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    height: 1,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shopName.isEmpty
                                      ? 'Cửa hàng của bạn'
                                      : shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: AppFontSize.titleLarge,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Badge(
                            isLabelVisible: unread > 0,
                            label: Text(unread > 99 ? '99+' : '$unread'),
                            backgroundColor: AppColors.danger,
                            offset: const Offset(-2, 2),
                            child: IconButton(
                              tooltip: unread > 0
                                  ? '$unread thông báo chưa đọc'
                                  : 'Thông báo',
                              onPressed: () => context.push('/notifications'),
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(44),
                                backgroundColor:
                                    Colors.white.withValues(alpha: .70),
                                foregroundColor: AppColors.textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                size: 23,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/profile'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Ink(
                    height: 56 * textScale,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDE6),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Địa chỉ lấy hàng',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                height: 1.1,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shopAddress.isEmpty
                                  ? 'Thêm địa chỉ cửa hàng'
                                  : shopAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w600,
                                color: shopAddress.isEmpty
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      textScale != oldDelegate.textScale ||
      shopName != oldDelegate.shopName ||
      shopAddress != oldDelegate.shopAddress ||
      unread != oldDelegate.unread;
}

class _TodayOverviewCard extends StatelessWidget {
  final TodayStats stats;
  final bool loading;
  final VoidCallback onTap;

  const _TodayOverviewCard({
    required this.stats,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _HomeSurface(
      onTap: onTap,
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final metrics = [
          _TodayMetric(
            icon: Icons.receipt_long_outlined,
            value: loading ? '—' : '${stats.orders}',
            label: 'Tổng đơn',
            color: c.primary,
            compact: compact,
          ),
          _TodayMetric(
            icon: Icons.check_circle_outline_rounded,
            value: loading ? '—' : '${stats.completed}',
            label: 'Hoàn thành',
            color: c.success,
            compact: compact,
          ),
          _TodayMetric(
            icon: Icons.local_shipping_outlined,
            value: loading ? '—' : '${stats.active}',
            label: 'Đang xử lý',
            color: c.info,
            compact: compact,
          ),
        ];
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LayoutBuilder(builder: (context, revenueConstraints) {
                  final label = Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: c.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Phí giao hàng hôm nay',
                              maxLines: 1,
                              style: AppTextStyles.label.copyWith(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tổng phí các đơn trong ngày',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]);
                  final amount = SizedBox(
                    key: const ValueKey('today-shipping-fee'),
                    width: revenueConstraints.maxWidth * .42,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          loading ? '—' : Fmt.currency(stats.revenue),
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.screenTitle.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                  return Row(children: [
                    Expanded(child: label),
                    const SizedBox(width: 10),
                    Flexible(child: amount),
                  ]);
                }),
              ),
              const SizedBox(height: 14),
              if (compact)
                for (var i = 0; i < metrics.length; i++) ...[
                  metrics[i],
                  if (i < metrics.length - 1)
                    Divider(height: 13, indent: 42, color: c.divider),
                ]
              else
                IntrinsicHeight(
                  child: Row(children: [
                    Expanded(child: metrics[0]),
                    VerticalDivider(width: 17, color: c.divider),
                    Expanded(child: metrics[1]),
                    VerticalDivider(width: 17, color: c.divider),
                    Expanded(child: metrics[2]),
                  ]),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool compact;

  const _TodayMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconBox = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 17, color: color),
    );
    final amount = Text(
      value,
      maxLines: 1,
      style: AppTextStyles.screenTitle.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
    final caption = Text(
      label,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption.copyWith(color: c.textSecondary),
    );
    if (compact) {
      return Row(children: [
        iconBox,
        const SizedBox(width: 10),
        Expanded(child: caption),
        const SizedBox(width: 8),
        amount,
      ]);
    }
    return Column(children: [
      iconBox,
      const SizedBox(height: 8),
      amount,
      const SizedBox(height: 3),
      caption,
    ]);
  }
}
