part of '../screens/home_screen.dart';

class _Header extends ConsumerWidget {
  final String shopName;
  final String shopAddress;
  final TodayStats? today;

  const _Header({
    required this.shopName,
    required this.shopAddress,
    this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final top = MediaQuery.of(context).padding.top;
    final stats = today ?? const TodayStats();

    // Header gradient cam đồng bộ app tài xế: tên cửa hàng + chuông ở trên,
    // phí ship hôm nay và 3 chỉ số trong khối kính mờ ở dưới.
    return GradientHeaderShell(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSize.xxl,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(shopAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppFontSize.base,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 23),
              ),
              if (unread > 0)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primaryGradientMiddle, width: 1.5),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PHÍ SHIP HÔM NAY',
              style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text(Fmt.currency(stats.revenue),
              style: const TextStyle(
                  fontSize: AppFontSize.hero,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.orders}', label: 'ĐƠN HÔM NAY')),
              Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.3)),
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.active}', label: 'ĐANG XỬ LÝ')),
              Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.3)),
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.completed}', label: 'HOÀN THÀNH')),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _HomeMetric extends StatelessWidget {
  final String value;
  final String label;
  const _HomeMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: AppFontSize.xxl,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
      const SizedBox(height: 2),
      Text(label,
          maxLines: 1,
          style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85))),
    ]);
  }
}
