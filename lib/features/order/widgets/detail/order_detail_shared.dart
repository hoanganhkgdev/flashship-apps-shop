part of '../../screens/order_detail_screen.dart';

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  final Widget child;
  const _FlatCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: context.colors.cardShadow,
        ),
        child: child,
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
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: context.isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary)),
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
        Icon(Icons.wifi_off_rounded, size: 48, color: c.textSecondary),
        const SizedBox(height: 12),
        Text('Không thể tải đơn hàng',
            style: TextStyle(fontSize: 14, color: c.textSecondary)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ]),
    );
  }
}
