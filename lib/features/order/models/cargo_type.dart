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
  CargoType('food',    'Đồ ăn',          Icons.lunch_dining_rounded,  Color(0xFFF59E0B)),
  CargoType('flowers', 'Hoa / Trái cây', Icons.local_florist_rounded, Color(0xFFEC4899)),
  CargoType('parcel',  'Bưu kiện',       Icons.inventory_2_rounded,   Color(0xFF6B7280),
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
