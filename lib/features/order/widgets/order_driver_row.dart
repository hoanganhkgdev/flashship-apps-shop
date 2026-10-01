import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../models/order_model.dart';

/// Dòng tài xế phụ trách đơn kèm nút gọi nhanh.
class OrderDriverRow extends StatelessWidget {
  final DriverInfo driver;
  const OrderDriverRow({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = driver.name.trim().isEmpty ? 'Tài xế' : driver.name.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(Icons.two_wheeler_rounded, size: 18, color: c.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
        ),
        if (driver.phone.isNotEmpty)
          IconButton(
            tooltip: 'Gọi tài xế',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.call_rounded, size: 20, color: c.success),
            onPressed: () => callPhone(driver.phone),
          ),
      ]),
    );
  }
}
