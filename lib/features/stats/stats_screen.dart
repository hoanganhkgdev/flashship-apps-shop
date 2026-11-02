import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_decor_widgets.dart';
import '../../core/widgets/app_form_widgets.dart';
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
      backgroundColor: c.background,
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Thống '),
                        TextSpan(
                          text: 'kê',
                          style: TextStyle(color: c.primary),
                        ),
                      ]),
                      style: AppTextStyles.screenTitle.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.insights_rounded, size: 15, color: c.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Theo dõi hiệu quả hoạt động của cửa hàng',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _PeriodTabs(
                      selected: period,
                      onChanged: (value) =>
                          ref.read(_statsPeriodProvider.notifier).state = value,
                    ),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD1BF)),
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
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: AppDuration.normal,
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? c.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    period.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: active ? Colors.white : c.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppBottomNav.reservedHeight(context) + 16,
      ),
      children: [
        // ── Phí ship + tỷ lệ hoàn thành ───────────────────────────────
        _card(
          context,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _FlatIcon(
                  icon: Icons.payments_rounded,
                  color: c.primary,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Tổng phí ship',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('$completed đơn',
                      style: AppTextStyles.caption.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.currency(revenue),
                    style: AppTextStyles.metricLarge.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    )),
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
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
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
          warm: true,
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

  Widget _card(BuildContext context, Widget child, {bool warm = false}) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warm ? c.primarySoft : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warm ? const Color(0xFFFFD1BF) : c.divider,
        ),
      ),
      child: child,
    );
  }
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
        Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (subtitle != null) ...[
          Icon(icon, size: 15, color: c.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _FlatIcon(icon: icon, color: color, size: 36),
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
            style: AppTextStyles.metricLarge.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
            )),
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
        _FlatIcon(icon: icon, color: color, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$count đơn · ${(pct * 100).toStringAsFixed(0)}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.label.copyWith(color: c.textSecondary),
                ),
              ),
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

class _FlatIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _FlatIcon({
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: size * .52, color: color),
      );
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
