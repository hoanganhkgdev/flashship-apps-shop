import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CargoType {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool hasWeight;
  const CargoType(this.key, this.label, this.icon, this.color,
      {this.hasWeight = false});
}

const cargoTypes = [
  CargoType('food', 'Thực phẩm', Icons.lunch_dining_rounded, Color(0xFFF59E0B)),
  CargoType(
      'flowers', 'Giỏ hoa', Icons.local_florist_rounded, Color(0xFFEC4899)),
  CargoType('parcel', 'Kiện hàng', Icons.inventory_2_rounded, Color(0xFF6B7280),
      hasWeight: true),
];

CargoType cargoTypeOf(String key) =>
    cargoTypes.firstWhere((c) => c.key == key, orElse: () => cargoTypes.last);

/// Style của chip chọn loại hàng: nền màu nhạt + viền khi được chọn,
/// nền xám trung tính khi chưa chọn. Dùng chung giữa các màn tạo đơn.
BoxDecoration cargoChipDecoration(bool selected, Color color) => BoxDecoration(
      color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: selected ? Border.all(color: color, width: 1.5) : null,
    );

/// Ô chọn loại hàng dùng chung giữa các màn tạo đơn.
class CargoTile extends StatelessWidget {
  final CargoType cargo;
  final bool selected;
  final VoidCallback onTap;
  const CargoTile(
      {super.key,
      required this.cargo,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? cargo.color.withValues(alpha: 0.1) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: selected ? cargo.color : Colors.transparent, width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(cargo.icon,
              size: AppSize.iconLg,
              color: selected ? cargo.color : c.textTertiary),
          const SizedBox(height: AppSpacing.xs),
          Text(cargo.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? c.textPrimary : c.textSecondary)),
        ]),
      ),
    );
  }
}
