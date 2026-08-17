import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Thanh chỉ báo N bước — đoạn đã qua tô [AppColors.primary], đoạn còn lại
/// tô màu nền nhạt, kèm text "Bước x/N" bên phải. Dùng cho các flow nhiều
/// bước trong 1 màn hình (đăng ký, quên mật khẩu…).
class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(totalSteps, (i) {
              final active = i < currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i == totalSteps - 1 ? 0 : AppSpace.xs),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Text('Bước $currentStep/$totalSteps',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            )),
      ],
    );
  }
}
