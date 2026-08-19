import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QuickAction {
  final IconData      icon;
  final Color         color;
  final String        label;
  final VoidCallback  onTap;
  const QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

/// Hàng thao tác nhanh — icon tròn nhỏ (44px) nền tint nhạt theo màu thao
/// tác, icon màu đơn sắc, label nhỏ bên dưới. KHÔNG bọc card ngoài, tap
/// target rõ ràng nhưng compact — thay cho các _ServiceCard to trang trí.
class QuickActionBar extends StatelessWidget {
  final List<QuickAction> items;
  const QuickActionBar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: items.map((a) => Expanded(
        child: InkWell(
          onTap: a.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: a.color.withValues(
                      alpha: context.isDark ? 0.18 : 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
            ]),
          ),
        ),
      )).toList(),
    );
  }
}
