import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/cities_provider.dart';

/// Bottom sheet chọn khu vực dùng chung giữa màn đăng ký và hồ sơ cửa hàng.
Future<CityItem?> showCityPicker(
  BuildContext context, {
  required List<CityItem> cities,
  int? selectedId,
  String title = 'Chọn khu vực',
  bool showHandle = false,
  bool highlightSelected = false,
}) {
  return showModalBottomSheet<CityItem>(
    context: context,
    shape: showHandle
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)))
        : null,
    builder: (sheetCtx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHandle) ...[
          const SizedBox(height: 4),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const Divider(height: 1),
        ...cities.map((city) {
          final selected = city.id == selectedId;
          return ListTile(
            title: Text(city.name,
                style: highlightSelected
                    ? TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? sheetCtx.colors.primary
                            : sheetCtx.colors.textPrimary)
                    : null),
            trailing: selected
                ? Icon(Icons.check_rounded, color: sheetCtx.colors.primary, size: 18)
                : null,
            onTap: () => Navigator.pop(sheetCtx, city),
          );
        }),
        const SizedBox(height: 8),
      ],
    ),
  );
}
