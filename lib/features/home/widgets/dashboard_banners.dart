part of '../screens/home_screen.dart';

// ─── Banner thông báo/khuyến mãi ───────────────────────────────────────────────
// TODO: đang hardcode _homeBanners tĩnh. Khi backend có endpoint thông báo hệ
// thống (vd GET /shop/announcements), thay bằng 1 provider fetch danh sách rồi
// truyền vào _HomeBannerSection — widget đã sẵn carousel cho trường hợp >1 banner.

class _BannerItem {
  final IconData icon;
  final String title;
  final String route;
  const _BannerItem({
    required this.icon,
    required this.title,
    required this.route,
  });
}

const _homeBanners = <_BannerItem>[
  _BannerItem(
    icon: Icons.campaign_rounded,
    title: 'Ưu đãi phí giao hàng tuần này — giảm đến 15% cho đơn nội thành',
    route: '/notifications',
  ),
];

// ─── Banner nhắc cập nhật mềm ───────────────────────────────────────────────
//
// Khác dialog "Cập nhật bắt buộc" (main.dart) — không chặn thao tác, có thể
// bấm "Để sau" để ẩn cho đúng phiên bản này (xem dismissedSoftUpdateVersionProvider).
class _SoftUpdateBanner extends ConsumerWidget {
  const _SoftUpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    final dismissedVersion = ref.watch(dismissedSoftUpdateVersionProvider);

    final shouldShow = version.needsSoftUpdate &&
        version.latestVersion != null &&
        version.latestVersion != dismissedVersion;
    if (!shouldShow) return const SizedBox.shrink();

    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(Icons.system_update_rounded, color: c.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Đã có bản cập nhật mới',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              final v = version.latestVersion;
              if (v != null) {
                ref
                    .read(dismissedSoftUpdateVersionProvider.notifier)
                    .dismiss(v);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Để sau',
                style: TextStyle(
                    fontSize: AppFontSize.sm, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => openStore(version.storeUrl),
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cập nhật',
                style: TextStyle(
                    fontSize: AppFontSize.sm, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// Giữ lại để có thể tái sử dụng khi mockup bổ sung carousel khuyến mãi.
// ignore: unused_element
class _HomeBannerSection extends StatelessWidget {
  const _HomeBannerSection();

  @override
  Widget build(BuildContext context) {
    if (_homeBanners.isEmpty) return const SizedBox.shrink();

    if (_homeBanners.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _BannerCard(item: _homeBanners.first),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        itemCount: _homeBanners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          child: _BannerCard(item: _homeBanners[i]),
        ),
      ),
    );
  }
}

// Thu gọn thành 1 dòng mỏng — banner khuyến mãi không phải ưu tiên hàng đầu
// của công cụ vận hành, chỉ cần đủ nhận diện, không chiếm nhiều diện tích.
class _BannerCard extends StatelessWidget {
  final _BannerItem item;
  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push(item.route),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: c.cardShadow,
        ),
        child: Row(children: [
          Icon(item.icon, color: c.primary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 16),
        ]),
      ),
    );
  }
}
