part of '../screens/home_screen.dart';

// ─── Header ───────────────────────────────────────────────────────────────────

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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Hình tròn trang trí mờ — đồng bộ hero header app driver ──
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 110,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Tên shop + bell ────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xin chào 👋',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                                color: Colors.white.withValues(alpha: 0.85))),
                        const SizedBox(height: 2),
                        Text(shopName,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                                shadows: [
                                  Shadow(
                                      color: Color(0x26000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1)),
                                ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (shopAddress.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.location_on_rounded,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 3),
                            Flexible(
                                child: Text(shopAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.white
                                            .withValues(alpha: 0.85)))),
                          ]),
                        ],
                      ]),
                ),
                const SizedBox(width: 12),
                // ── Bell icon với badge ──────────────────────────────────
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: c.primary)),
                        ),
                      ),
                  ]),
                ),
              ]),

              // ── Thống kê hôm nay — thẻ trắng nổi bằng shadow trên nền
              // gradient (giống card toggle của app driver) ───────────────
              if (today != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: StatRow(items: [
                    StatItem(value: '${today!.orders}', label: 'Đơn hôm nay'),
                    StatItem(
                      value: '${today!.active}',
                      label: 'Đang chạy',
                      valueColor: today!.active > 0 ? c.primary : null,
                    ),
                    StatItem(
                      value: today!.revenue >= 1000
                          ? '${(today!.revenue / 1000).toStringAsFixed(0)}K'
                          : '${today!.revenue}đ',
                      label: 'Doanh thu',
                      valueColor: today!.revenue > 0 ? c.success : null,
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Ô dịch vụ ────────────────────────────────────────────────────────────────
// Nền tint nhạt theo màu + viền cùng tông (alpha 0.07/0.18) — cùng pattern
// với ô "Ví cá nhân"/"Công nợ" trong FinanceCard của app driver.
