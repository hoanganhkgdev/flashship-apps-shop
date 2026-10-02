import '../../../core/widgets/app_decor_widgets.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../models/order_model.dart';

/// Dòng tài xế phụ trách đơn: avatar chữ cái, tên, nhãn vai trò và nút gọi.
class OrderDriverRow extends StatelessWidget {
  final DriverInfo driver;
  const OrderDriverRow({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = driver.name.trim().isEmpty ? 'Tài xế' : driver.name.trim();
    final initial = name.characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent2.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(initial,
              style: AppTextStyles.bodyStrong.copyWith(color: c.accent2)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              Text('Tài xế phụ trách',
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w500, color: c.textSecondary)),
            ],
          ),
        ),
        if (driver.phone.isNotEmpty)
          GlassIconButton(
            icon: Icons.call_rounded,
            iconSize: AppSize.iconMd,
            color: c.success,
            tooltip: 'Gọi tài xế',
            onPressed: () => callPhone(driver.phone),
          ),
      ]),
    );
  }
}
