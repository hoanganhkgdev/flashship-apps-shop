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
    final c = context.colors;
    final top = MediaQuery.of(context).padding.top;
    final stats = today ?? const TodayStats();

    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, top + 18, 20, 16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child:
                Icon(Icons.location_on_outlined, color: c.onPrimary, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(shopAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
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
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.divider),
                ),
                child: Icon(Icons.notifications_none_rounded,
                    color: c.textPrimary, size: 23),
              ),
              if (unread > 0)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PHÍ SHIP HÔM NAY',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textTertiary)),
            const SizedBox(height: 7),
            Text(Fmt.currency(stats.revenue),
                style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            const SizedBox(height: 18),
            Divider(height: 1, color: c.divider),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.orders}', label: 'ĐƠN HÔM NAY')),
              Container(width: 1, height: 36, color: c.divider),
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.active}',
                      label: 'ĐANG XỬ LÝ',
                      color: c.info)),
              Container(width: 1, height: 36, color: c.divider),
              Expanded(
                  child: _HomeMetric(
                      value: '${stats.completed}',
                      label: 'HOÀN THÀNH',
                      color: c.success)),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _HomeMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _HomeMetric({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color ?? c.textPrimary)),
      const SizedBox(height: 2),
      Text(label,
          maxLines: 1,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: c.textTertiary)),
    ]);
  }
}
