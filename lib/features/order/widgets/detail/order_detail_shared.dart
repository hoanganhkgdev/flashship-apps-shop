part of '../../screens/order_detail_screen.dart';

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  final Widget child;

  /// Màu vầng sáng mờ ở góc card (vd màu trạng thái đơn).
  final Color? glow;
  const _FlatCard({required this.child, this.glow});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          child: GlassCard(blur: false, glow: glow, child: child),
        ),
      );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _CardHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        AppIconBadge(icon: icon, color: iconColor, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label,
              style: AppTextStyles.sectionTitle
                  .copyWith(color: context.colors.textPrimary)),
        ),
      ]);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AppIconBadge(
            icon: Icons.wifi_off_rounded, color: c.textSecondary, size: 64),
        const SizedBox(height: AppSpacing.lg),
        Text('Không thể tải đơn hàng',
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text('Kiểm tra kết nối rồi thử lại',
            style: AppTextStyles.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonal(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
              minimumSize: const Size(140, AppSize.buttonHeight),
              backgroundColor: c.primarySoft,
              foregroundColor: c.primary),
          child: const Text('Thử lại'),
        ),
      ]),
    );
  }
}
