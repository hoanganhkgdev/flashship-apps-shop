import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_decor_widgets.dart';
import '../order/models/cargo_type.dart';
import 'stats_repository.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _statsPeriodProvider = StateProvider<String>((ref) => 'week');

const _periods = [
  ('today', 'Hôm nay'),
  ('week', 'Tuần này'),
  ('month', 'Tháng này'),
];

final _statsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, period) async {
  return ref.read(statsRepositoryProvider).fetch(period: period);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final period = ref.watch(_statsPeriodProvider);
    final statsAsync = ref.watch(_statsProvider(period));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.paddingOf(context).top + AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(children: [
              AppIconBadge(
                  icon: Icons.bar_chart_rounded, color: c.primary, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thống kê',
                      style: AppTextStyles.screenTitle.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Tổng quan hoạt động cửa hàng',
                      style:
                          AppTextStyles.label.copyWith(color: c.textSecondary)),
                ],
              )),
            ]),
          ),
          _PeriodTabs(
            selected: period,
            onChanged: (value) =>
                ref.read(_statsPeriodProvider.notifier).state = value,
          ),

          // ── Content ─────────────────────────────────────────────────
          Expanded(
            child: statsAsync.when(
              loading: () => Center(
                  child: CircularProgressIndicator(
                      color: c.primary, strokeWidth: 2)),
              error: (_, __) => RefreshIndicator(
                color: c.primary,
                onRefresh: () async {
                  ref.invalidate(_statsProvider(period));
                  await ref.read(_statsProvider(period).future);
                },
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Center(
                          child: AppIconBadge(
                              icon: Icons.wifi_off_rounded,
                              color: c.textSecondary,
                              size: 64)),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                          child: Text('Không tải được dữ liệu',
                              style: AppTextStyles.bodyStrong
                                  .copyWith(color: c.textPrimary))),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                          child: FilledButton.tonal(
                        onPressed: () => ref.invalidate(_statsProvider(period)),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(140, AppSize.buttonHeight),
                            backgroundColor: c.primarySoft,
                            foregroundColor: c.primary),
                        child: const Text('Thử lại'),
                      )),
                    ]),
              ),
              data: (stats) => RefreshIndicator(
                color: c.primary,
                onRefresh: () async {
                  ref.invalidate(_statsProvider(period));
                  await ref.read(_statsProvider(period).future);
                },
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

class _PeriodTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: context.isDark ? .08 : .6),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: Colors.white.withValues(alpha: context.isDark ? .2 : .9),
              width: 1.2),
        ),
        child: Row(
          children: _periods.map((period) {
            final active = selected == period.$1;
            return Expanded(
              child: Semantics(
                button: true,
                selected: active,
                child: InkWell(
                  onTap: () => onChanged(period.$1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: AnimatedContainer(
                    duration: AppDuration.normal,
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: active ? c.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: c.primary.withValues(alpha: .35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(period.$2,
                        style: AppTextStyles.label.copyWith(
                          color: active ? Colors.white : c.textSecondary,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = Fmt.toInt(stats['total']);
    final active = Fmt.toInt(stats['active']);
    final completed = Fmt.toInt(stats['completed']);
    final cancelled = Fmt.toInt(stats['cancelled']);
    final revenue = Fmt.toInt(stats['revenue']);
    final cargoMap = stats['by_cargo_type'] is Map
        ? Map<String, dynamic>.from(stats['by_cargo_type'] as Map)
        : <String, dynamic>{};

    final completionRate =
        total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final cargoTotal =
        cargoMap.values.fold<int>(0, (sum, value) => sum + Fmt.toInt(value));
    final daily = stats['daily'] is List ? stats['daily'] as List : <dynamic>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl4),
      children: [
        // ── Phí ship + tỷ lệ hoàn thành ───────────────────────────────
        _card(
          context,
          glow: c.success,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AppIconBadge(
                    icon: Icons.payments_rounded, color: c.success, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Tổng phí ship',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: c.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: c.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('$completed đơn',
                      style: AppTextStyles.caption.copyWith(color: c.success)),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.currency(revenue),
                    style:
                        AppTextStyles.metricLarge.copyWith(color: c.success)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Tổng chi phí giao hàng trong kỳ đã chọn',
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: c.divider),
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: Text('Tỷ lệ hoàn thành',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary)),
                ),
                Text(
                    total == 0
                        ? '—'
                        : '${(completionRate * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.success)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    minHeight: 8,
                    color: c.success,
                    backgroundColor: c.surfaceAlt,
                  )),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  total == 0
                      ? 'Chưa có đơn hàng trong khoảng thời gian này'
                      : '$completed / $total đơn hàng đã hoàn thành',
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),

        // ── Tổng quan đơn hàng ───────────────────────────────────────
        _SectionTitle(Icons.receipt_long_rounded, 'Tổng quan đơn hàng'),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 600 ? 4 : 2;
          const gap = AppSpacing.md;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final metric in [
              ('Tổng đơn', total, Icons.receipt_long_rounded, c.primary),
              ('Đang xử lý', active, Icons.local_shipping_rounded, c.info),
              ('Hoàn thành', completed, Icons.check_circle_rounded, c.success),
              ('Đã huỷ', cancelled, Icons.cancel_rounded, c.danger),
            ])
              SizedBox(
                  width: (width - (columns - 1) * gap) / columns,
                  child: _StatCard(
                      label: metric.$1,
                      value: metric.$2.toString(),
                      icon: metric.$3,
                      color: metric.$4)),
          ]);
        }),
        const SizedBox(height: AppSpacing.xl2),

        // ── Nhịp độ ──────────────────────────────────────────────────
        _SectionTitle(Icons.bar_chart_rounded, 'Nhịp độ đơn hàng',
            subtitle: '7 ngày gần nhất'),
        _card(
            context,
            daily.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl2),
                    child: Center(
                        child: Text('Chưa có dữ liệu biểu đồ',
                            style: AppTextStyles.body
                                .copyWith(color: c.textTertiary))))
                : _DailyChart(daily: daily)),

        // ── Loại hàng ────────────────────────────────────────────────
        if (cargoMap.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl2),
          _SectionTitle(Icons.category_rounded, 'Phân bố loại hàng'),
          _card(
              context,
              Column(children: [
                for (final cargo in cargoTypes) ...[
                  if (cargo.key != cargoTypes.first.key)
                    Divider(
                        height: 1,
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                        color: c.divider),
                  _CargoRow(
                      icon: cargo.icon,
                      label: cargo.label,
                      count: Fmt.toInt(cargoMap[cargo.key]),
                      color: cargo.color,
                      total: cargoTotal),
                ],
              ])),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, Widget child, {Color? glow}) => SizedBox(
        width: double.infinity,
        child: GlassCard(
          blur: false,
          glow: glow,
          padding: EdgeInsets.zero,
          child: child,
        ),
      );
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  const _SectionTitle(this.icon, this.label, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(children: [
        AppIconBadge(icon: icon, color: c.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
        ),
        if (subtitle != null)
          Text(subtitle!,
              style: AppTextStyles.label.copyWith(color: c.textTertiary)),
      ]),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      blur: false,
      glow: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIconBadge(icon: icon, color: color, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(color: c.textSecondary)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text(value,
            style: AppTextStyles.metricLarge.copyWith(color: c.textPrimary)),
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
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(children: [
        AppIconBadge(icon: icon, color: color, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              const Spacer(),
              Text('$count đơn · ${(pct * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: c.surfaceAlt,
                color: color,
                minHeight: 6,
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

  static const _chartHeight = 130.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final chartData = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dynamic match;
      for (final item in daily) {
        if (item is Map && item['date']?.toString() == key) {
          match = item;
          break;
        }
      }
      return <String, dynamic>{
        'date': key,
        'count': match == null ? 0 : Fmt.toInt(match['count']),
      };
    });
    final maxCount = chartData
        .map((d) => Fmt.toInt(d['count']))
        .fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xl2, AppSpacing.md, AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartData.map((d) {
          final count = Fmt.toInt(d['count']);
          final date = d['date'] as String? ?? '';
          final label = date.length >= 10
              ? '${date.substring(8, 10)}/${date.substring(5, 7)}'
              : date;
          final ratio = maxCount > 0 ? count / maxCount : 0.0;
          final isMax = count > 0 && count == maxCount;
          final barHeight =
              (ratio.clamp(0.0, 1.0) * _chartHeight).clamp(4.0, _chartHeight);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Hiển thị số đơn trên từng cột.
                  SizedBox(
                    height: 20,
                    child: Text('$count',
                        style: AppTextStyles.caption.copyWith(
                            color: isMax ? c.primary : c.textSecondary)),
                  ),
                  const SizedBox(height: 4),

                  // Cột
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: count == 0
                          ? c.surfaceAlt
                          : isMax
                              ? c.primary
                              : c.primary.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nhãn ngày
                  Text(label,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w500, color: c.textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
