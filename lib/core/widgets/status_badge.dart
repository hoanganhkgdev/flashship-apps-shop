import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Badge trạng thái dùng thống nhất cho MỌI trạng thái đơn hàng xuất hiện ở
/// bất kỳ đâu trong app (danh sách, chi tiết, trang chủ...) — thay cho mỗi
/// nơi tự vẽ badge trạng thái riêng.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}
