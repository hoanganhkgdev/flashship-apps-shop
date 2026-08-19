import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../order/models/cargo_type.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _statsPeriodProvider = StateProvider<String>((ref) => 'week');

const _periods = [
  ('today', 'Hôm nay'),
  ('week',  'Tuần này'),
  ('month', 'Tháng này'),
];

final _statsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final res = await ref.read(apiClientProvider)
      .get('/shop/orders/stats', params: {'period': period});
  return unwrap(res) as Map<String, dynamic>;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c          = context.colors;
    final period     = ref.watch(_statsPeriodProvider);
    final statsAsync = ref.watch(_statsProvider(period));

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              color: c.surface,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 16),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Thống kê',
                      style: TextStyle(fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Tổng quan hoạt động cửa hàng',
                      style: TextStyle(fontSize: 12,
                          color: c.textSecondary)),
                ]),
                const Spacer(),
                statsAsync.isLoading
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: c.primary))
                    : GestureDetector(
                        onTap: () => ref.invalidate(_statsProvider(period)),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.refresh_rounded,
                              color: c.primary, size: 18),
                        ),
                      ),
              ]),
            ),

            // ── Bộ lọc khoảng thời gian ─────────────────────────────────
            Container(
              color: c.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: _periods.map((p) {
                    final selected = period == p.$1;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(_statsPeriodProvider.notifier).state = p.$1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: selected ? c.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: selected
                                ? [BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1))]
                                : null,
                          ),
                          child: Center(
                            child: Text(p.$2,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? c.primary
                                        : c.textSecondary)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: statsAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(
                        color: c.primary, strokeWidth: 2)),
                error: (_, __) => RefreshIndicator(
                  color: c.primary,
                  onRefresh: () async => ref.invalidate(_statsProvider(period)),
                  child: ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.wifi_off_rounded,
                          size: 34, color: c.textTertiary),
                    )),
                    const SizedBox(height: 14),
                    Center(child: Text('Không tải được dữ liệu',
                        style: TextStyle(color: c.textSecondary,
                            fontSize: 14, fontWeight: FontWeight.w600))),
                  ]),
                ),
                data: (stats) => RefreshIndicator(
                  color: c.primary,
                  onRefresh: () async => ref.invalidate(_statsProvider(period)),
                  child: _StatsContent(stats: stats),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _StatsContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final total     = Fmt.toInt(stats['total']);
    final active    = Fmt.toInt(stats['active']);
    final completed = Fmt.toInt(stats['completed']);
    final cancelled = Fmt.toInt(stats['cancelled']);
    final revenue   = Fmt.toInt(stats['revenue']);
    final cargoMap  = stats['by_cargo_type'] is Map
        ? Map<String, dynamic>.from(stats['by_cargo_type'] as Map)
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // ── Revenue hero — số liệu trần trên nền trắng, không gradient ────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.divider),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.payments_outlined, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('Tổng doanh thu',
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(Fmt.currency(revenue),
                style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('$completed đơn hoàn thành',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ]),
        ),

        const SizedBox(height: 14),

        // ── 4 stat cards (2×2 grid) ──────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Tổng đơn',
            value: total.toString(),
            icon: Icons.receipt_long_rounded,
            color: c.textSecondary,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            label: 'Đang chạy',
            value: active.toString(),
            icon: Icons.local_shipping_rounded,
            color: c.info,
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Hoàn thành',
            value: completed.toString(),
            icon: Icons.check_circle_rounded,
            color: c.success,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            label: 'Đã huỷ',
            value: cancelled.toString(),
            icon: Icons.cancel_rounded,
            color: c.danger,
          )),
        ]),

        // ── Cargo breakdown ─────────────────────────────────────────────
        if (cargoMap.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.category_rounded,
              label: 'Theo loại hàng'),
          const SizedBox(height: 10),
          _card(c, Column(children: [
            for (final cargo in cargoTypes) ...[
              if (cargo.key != cargoTypes.first.key)
                Divider(height: 1, color: c.divider),
              _CargoRow(
                icon: cargo.icon,
                label: cargo.label,
                count: Fmt.toInt(cargoMap[cargo.key]),
                color: cargo.color,
                total: completed,
              ),
            ],
          ])),
        ],

        // ── Daily 7 ngày ────────────────────────────────────────────────
        if ((stats['daily'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.bar_chart_rounded,
              label: '7 ngày gần nhất'),
          const SizedBox(height: 10),
          _card(c, _DailyChart(daily: stats['daily'] as List)),
        ],
      ],
    );
  }

  Widget _card(Palette c, Widget child) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.divider),
        ),
        child: child,
      );
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: 15, color: c.textSecondary),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textSecondary)),
    ]);
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 12),
        Text(value,
            style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12,
                color: c.textSecondary)),
      ]),
    );
  }
}

// ─── Cargo Row ────────────────────────────────────────────────────────────────

class _CargoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count, total;
  final Color    color;

  const _CargoRow({
    required this.icon,  required this.label,
    required this.count, required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c   = context.colors;
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
              const Spacer(),
              Text('$count đơn',
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: c.surfaceAlt,
                color: color,
                minHeight: 5,
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

// ─── Daily Chart ──────────────────────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  final List<dynamic> daily;
  const _DailyChart({required this.daily});

  static const _chartHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final maxCount = daily.map((d) => Fmt.toInt(d['count'])).fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: daily.map((d) {
          final count = Fmt.toInt(d['count']);
          final date  = d['date'] as String? ?? '';
          final label = date.length >= 10 ? date.substring(5) : date;
          final ratio = maxCount > 0 ? count / maxCount : 0.0;
          final isMax = count > 0 && count == maxCount;
          final barHeight = (ratio.clamp(0.0, 1.0) * _chartHeight).clamp(4.0, _chartHeight);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Số đơn — chỉ hiện trên cột cao nhất để tránh rối
                  SizedBox(
                    height: 16,
                    child: isMax
                        ? Text('$count',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.primary))
                        : null,
                  ),
                  const SizedBox(height: 4),

                  // Cột
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isMax ? c.primary : c.surfaceAlt,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nhãn ngày
                  Text(label,
                      style: TextStyle(fontSize: 10, color: c.textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
