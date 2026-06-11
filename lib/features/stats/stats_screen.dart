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
    final statsAsync = ref.watch(_statsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thống kê',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Kéo xuống để làm mới',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)),
                error: (_, __) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(_statsProvider),
                  child: ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Icon(Icons.wifi_off_rounded,
                          size: 48, color: AppColors.textSecondary)),
                      SizedBox(height: 12),
                      Center(child: Text('Không tải được dữ liệu',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14))),
                    ],
                  ),
                ),
                data: (stats) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(_statsProvider),
                  child: _StatsContent(stats: stats),
                ),
              ),
            ),
          ],
        ),
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
    final total     = _n(stats['total']);
    final active    = _n(stats['active']);
    final completed = _n(stats['completed']);
    final cancelled = _n(stats['cancelled']);
    final revenue   = _n(stats['revenue']);
    // PHP serializes empty associative arrays as [] — guard against it
    final cargoMap  = stats['by_cargo_type'] is Map
        ? Map<String, dynamic>.from(stats['by_cargo_type'] as Map)
        : <String, dynamic>{};

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),

        // ── Revenue card ────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng doanh thu',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(Fmt.currency(revenue),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text('$completed đơn hoàn thành',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            )),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.payments_rounded,
                  color: AppColors.primary, size: 24),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        // ── 4 stat tiles ────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _StatTile(
                label: 'Tổng đơn',
                value: total.toString(),
                icon: Icons.receipt_long_rounded,
                color: AppColors.textPrimary,
                showBorder: true,
              )),
              Expanded(child: _StatTile(
                label: 'Đang chạy',
                value: active.toString(),
                icon: Icons.local_shipping_rounded,
                color: AppColors.info,
              )),
            ]),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Row(children: [
              Expanded(child: _StatTile(
                label: 'Hoàn thành',
                value: completed.toString(),
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                showBorder: true,
              )),
              Expanded(child: _StatTile(
                label: 'Đã huỷ',
                value: cancelled.toString(),
                icon: Icons.cancel_rounded,
                color: AppColors.danger,
              )),
            ]),
          ]),
        ),

        const SizedBox(height: 8),

        // ── Cargo breakdown ─────────────────────────────────────────────
        if (cargoMap.isNotEmpty) ...[
          _SectionHeader('Theo loại hàng'),
          Container(
            color: Colors.white,
            child: Column(children: [
              _CargoRow(
                icon: Icons.lunch_dining_rounded,
                label: 'Đồ ăn',
                count: _n(cargoMap['food']),
                color: const Color(0xFFF59E0B),
                total: completed,
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
              _CargoRow(
                icon: Icons.local_florist_rounded,
                label: 'Hoa / Trái cây',
                count: _n(cargoMap['flowers']),
                color: const Color(0xFFEC4899),
                total: completed,
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
              _CargoRow(
                icon: Icons.inventory_2_rounded,
                label: 'Bưu kiện',
                count: _n(cargoMap['parcel']),
                color: const Color(0xFF6B7280),
                total: completed,
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        // ── Daily 7 ngày ────────────────────────────────────────────────
        if ((stats['daily'] as List?)?.isNotEmpty == true) ...[
          _SectionHeader('7 ngày gần nhất'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              ...(stats['daily'] as List).map((d) {
                final count = _n(d['count']);
                final rev   = _n(d['revenue']);
                final date  = (d['date'] as String? ?? '');
                final label = date.length >= 10 ? date.substring(5) : date;
                final maxCount = (stats['daily'] as List)
                    .map((x) => _n(x['count']))
                    .fold(1, (a, b) => a > b ? a : b);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? count / maxCount : 0,
                        backgroundColor: const Color(0xFFF0F0F0),
                        color: AppColors.primary,
                        minHeight: 6,
                      ),
                    )),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 50,
                      child: Text('$count đơn',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    if (rev > 0) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 72,
                        child: Text(Fmt.currency(rev),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ]),
                );
              }),
            ]),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Stat Tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool showBorder;

  const _StatTile({
    required this.label, required this.value,
    required this.icon,  required this.color,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: showBorder
          ? const BoxDecoration(
              border: Border(
                  right: BorderSide(color: Color(0xFFF0F0F0), width: 1)))
          : null,
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ─── Cargo Row ────────────────────────────────────────────────────────────────

class _CargoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count, total;
  final Color color;

  const _CargoRow({
    required this.icon,  required this.label,
    required this.count, required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFFF0F0F0),
                color: color,
                minHeight: 4,
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );
}
