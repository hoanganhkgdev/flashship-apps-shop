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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng,';
    if (hour < 14) return 'Chào buổi trưa,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  String get _initials {
    final parts =
        shopName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.map((p) => p[0].toUpperCase());
    return letters.length == 1
        ? letters.first
        : '${letters.first}${letters.last}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final c = context.colors;
    final top = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Avatar + tên shop + bell ─────────────────────────────────────
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, const Color(0xFFFF9A5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(_initials,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting,
                  style: TextStyle(fontSize: 13, color: c.textTertiary)),
              const SizedBox(height: 1),
              Text(shopName,
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: c.cardShadow,
                ),
                child: Icon(Icons.notifications_outlined,
                    color: c.textPrimary, size: 22),
              ),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
            ]),
          ),
        ]),

        // ── Hero doanh thu — thẻ gradient nổi bật ───────────────────────
        if (today != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF5D3B), const Color(0xFFEE5F6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: c.cardShadow,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Doanh thu hôm nay',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                              Fmt.dateTime(DateTime.now())
                                  .split(' ')
                                  .first
                                  .substring(0, 5),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(Fmt.currency(today!.revenue),
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _HeroStat(
                            value: '${today!.orders}', label: 'Đơn hôm nay'),
                      ),
                      Expanded(
                        child: _HeroStat(
                            value: '${today!.active}',
                            label: 'Đang giao',
                            highlight: today!.active > 0),
                      ),
                      Expanded(
                        child: _HeroStat(
                            value: '${today!.completed}', label: 'Hoàn thành'),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _HeroStat(
      {required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? const Color(0xFFFFE3D2) : Colors.white)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
    ]);
  }
}
