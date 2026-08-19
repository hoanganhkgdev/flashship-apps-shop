import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatItem {
  final String value;
  final String label;
  final Color? valueColor;
  const StatItem({required this.value, required this.label, this.valueColor});
}

/// Hàng số liệu ngang trần trên nền trang — KHÔNG bọc card/nền màu, ngăn cách
/// từng mục bằng đường kẻ dọc mảnh. Dùng cho tổng quan "hôm nay"/thống kê,
/// thay cho hero card màu/gradient.
class StatRow extends StatelessWidget {
  final List<StatItem> items;
  const StatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(width: 1, height: 32, color: c.divider),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(items[i].value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: items[i].valueColor ?? c.textPrimary)),
              const SizedBox(height: 2),
              Text(items[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ]),
          ),
        ],
      ],
    );
  }
}
