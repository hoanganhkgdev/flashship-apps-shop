part of '../../screens/order_detail_screen.dart';

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  final Widget child;
  final Color? glow;
  const _FlatCard({required this.child, this.glow});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: child,
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: iconColor, size: 19),
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
    ]);
  }
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
