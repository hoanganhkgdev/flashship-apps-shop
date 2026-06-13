import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

// ─── Helper ──────────────────────────────────────────────────────────────────

int _n(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0;

// ─── Provider ─────────────────────────────────────────────────────────────────

final _statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/shop/orders/stats');
  return (res.data['data'] ?? res.data) as Map<String, dynamic>;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c         = context.colors;
    final statsAsync = ref.watch(_statsProvider);

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
                        onTap: () => ref.invalidate(_statsProvider),
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

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: statsAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(
                        color: c.primary, strokeWidth: 2)),
                error: (_, __) => RefreshIndicator(
                  color: c.primary,
                  onRefresh: () async => ref.invalidate(_statsProvider),
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
                  onRefresh: () async => ref.invalidate(_statsProvider),
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
    final total     = _n(stats['total']);
    final active    = _n(stats['active']);
    final completed = _n(stats['completed']);
    final cancelled = _n(stats['cancelled']);
    final revenue   = _n(stats['revenue']);
    final cargoMap  = stats['by_cargo_type'] is Map
        ? Map<String, dynamic>.from(stats['by_cargo_type'] as Map)
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // ── Revenue hero card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.primary, const Color(0xFFCC5A08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.payments_rounded,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  const Text('Tổng doanh thu',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                ]),
                const SizedBox(height: 8),
                Text(Fmt.currency(revenue),
                    style: const TextStyle(fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('$completed đơn hoàn thành',
                    style: const TextStyle(fontSize: 12,
                        color: Colors.white70)),
              ],
            )),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 28),
            ),
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
            _CargoRow(
              icon: Icons.lunch_dining_rounded,
              label: 'Đồ ăn',
              count: _n(cargoMap['food']),
              color: const Color(0xFFF59E0B),
              total: completed,
            ),
            Divider(height: 1, color: c.divider),
            _CargoRow(
              icon: Icons.local_florist_rounded,
              label: 'Hoa / Trái cây',
              count: _n(cargoMap['flowers']),
              color: const Color(0xFFEC4899),
              total: completed,
            ),
            Divider(height: 1, color: c.divider),
            _CargoRow(
              icon: Icons.inventory_2_rounded,
              label: 'Bưu kiện',
              count: _n(cargoMap['parcel']),
              color: const Color(0xFF6B7280),
              total: completed,
            ),
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
          boxShadow: c.cardShadow,
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
        boxShadow: c.cardShadow,
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

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final maxCount = daily.map((d) => _n(d['count'])).fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: daily.map((d) {
          final count = _n(d['count']);
          final rev   = _n(d['revenue']);
          final date  = d['date'] as String? ?? '';
          final label = date.length >= 10 ? date.substring(5) : date;
          final ratio = maxCount > 0 ? count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              // Date label
              SizedBox(
                width: 40,
                child: Text(label,
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary)),
              ),
              const SizedBox(width: 8),

              // Bar
              Expanded(
                child: Stack(children: [
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.02, 1.0),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.primary,
                            c.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),

              // Count
              SizedBox(
                width: 44,
                child: Text('$count đơn',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: count == maxCount
                            ? c.primary
                            : c.textPrimary)),
              ),

              // Revenue (nếu có)
              if (rev > 0) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 68,
                  child: Text(Fmt.currency(rev),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10,
                          color: c.textSecondary)),
                ),
              ],
            ]),
          );
        }).toList(),
      ),
    );
  }
}
