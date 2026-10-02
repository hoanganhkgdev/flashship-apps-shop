part of '../screens/home_screen.dart';

/// Header cố định, cùng cấu trúc với DashboardHeader của Driver: nhận diện
/// tài khoản ở trái và hành động quan trọng ở phải. Số liệu được đưa xuống
/// vùng cuộn để header luôn gọn và không che nội dung trên màn hình nhỏ.
class _Header extends ConsumerWidget {
  final String shopName;
  final String shopAddress;

  const _Header({required this.shopName, required this.shopAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return GlassHeader(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xin chào 👋',
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle.copyWith(
                      color: c.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: unread > 0 ? '$unread thông báo chưa đọc' : 'Thông báo',
          child: Stack(clipBehavior: Clip.none, children: [
            GlassIconButton(
              icon: Icons.notifications_none_rounded,
              color: c.primary,
              tooltip: 'Thông báo',
              onPressed: () => context.push('/notifications'),
            ),
            if (unread > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Text(unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                          fontSize: AppFontSize.xs,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Card hoạt động hôm nay (liquid glass): phí ship nổi bật cùng vòng tiến độ
/// hoàn thành, ba ô số liệu bằng kính nhỏ bên dưới.
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
    final dark = context.isDark;
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
    final progress = stats.orders > 0
        ? (stats.completed / stats.orders).clamp(0.0, 1.0)
        : 0.0;
    final radius = BorderRadius.circular(AppRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark ? null : AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: .14),
                            Colors.white.withValues(alpha: .05),
                          ]
                        : [
                            Colors.white.withValues(alpha: .85),
                            Colors.white.withValues(alpha: .45),
                          ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: dark ? .22 : .9),
                      width: 1.2),
                ),
                child: Stack(children: [
                  // Vầng xanh lá mờ ở góc phải — nhấn vào số tiền.
                  Positioned(
                    top: -50,
                    right: -40,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          c.success.withValues(alpha: dark ? .25 : .22),
                          c.success.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            AppIconBadge(
                                icon: Icons.insights_rounded,
                                color: c.success,
                                size: 36),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hoạt động hôm nay',
                                      style: AppTextStyles.sectionTitle
                                          .copyWith(color: c.textPrimary)),
                                  Text(date,
                                      style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: c.textSecondary)),
                                ],
                              ),
                            ),
                            Text('Thống kê',
                                style: AppTextStyles.label
                                    .copyWith(color: c.primary)),
                            Icon(Icons.chevron_right_rounded,
                                size: AppSize.iconMd, color: c.primary),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PHÍ SHIP HÔM NAY',
                                      style: AppTextStyles.caption.copyWith(
                                          color: c.textTertiary,
                                          letterSpacing: .6)),
                                  const SizedBox(height: AppSpacing.xs),
                                  AnimatedSwitcher(
                                    duration: AppDuration.normal,
                                    child: loading
                                        ? Container(
                                            key:
                                                const ValueKey('today-loading'),
                                            width: 132,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: c.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.sm),
                                            ),
                                          )
                                        : FittedBox(
                                            key: const ValueKey('today-value'),
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                                Fmt.currency(stats.revenue),
                                                style: AppTextStyles.metricLarge
                                                    .copyWith(
                                                        color: c.success)),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _CompletionRing(progress: progress),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          Row(children: [
                            Expanded(
                              child: _TodayMetric(
                                icon: Icons.inventory_2_rounded,
                                value: '${stats.orders}',
                                label: 'Tổng đơn',
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TodayMetric(
                                icon: Icons.local_shipping_rounded,
                                value: '${stats.active}',
                                label: 'Đang xử lý',
                                color: c.info,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TodayMetric(
                                icon: Icons.check_circle_rounded,
                                value: '${stats.completed}',
                                label: 'Hoàn thành',
                                color: c.success,
                              ),
                            ),
                          ]),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vòng tiến độ: tỉ lệ đơn hoàn thành trong ngày.
class _CompletionRing extends StatelessWidget {
  final double progress;
  const _CompletionRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            color: c.success,
            backgroundColor: c.success.withValues(alpha: .18),
          ),
        ),
        Text('${(progress * 100).round()}%',
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
      ]),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TodayMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? .16 : .10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(children: [
        Icon(icon, size: AppSize.iconMd, color: color),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.metric.copyWith(color: c.textPrimary)),
        const SizedBox(height: AppSpacing.xxs),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary)),
      ]),
    );
  }
}
