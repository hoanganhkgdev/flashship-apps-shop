import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_decor_widgets.dart';
import '../providers/cities_provider.dart';

/// Bottom sheet chọn khu vực dùng chung giữa màn đăng ký và hồ sơ cửa hàng.
Future<CityItem?> showCityPicker(
  BuildContext context, {
  required List<CityItem> cities,
  int? selectedId,
  String title = 'Chọn khu vực',
}) {
  return showModalBottomSheet<CityItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.8),
      child: AppSheet(
        icon: Icons.location_city_rounded,
        title: title,
        child: Column(
          children: [
            for (final city in cities) ...[
              AppSheetOption(
                label: city.name,
                selected: city.id == selectedId,
                onTap: () => Navigator.pop(sheetCtx, city),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    ),
  );
}
