import 'package:flutter/material.dart';

class SupportConfigItem {
  final String title;
  final String type;
  final String value;

  /// Đường dẫn server đã chuẩn hoá để mở app (tel:, https://zalo.me/…, …).
  final String? link;

  const SupportConfigItem({
    required this.title,
    required this.type,
    required this.value,
    this.link,
  });

  factory SupportConfigItem.fromJson(Map<String, dynamic> json) =>
      SupportConfigItem(
        title: json['title'] as String,
        type: json['type'] as String? ?? 'other',
        value: json['value'] as String,
        link: json['link'] as String?,
      );

  IconData? get materialIcon => switch (type) {
        'phone' => Icons.phone_rounded,
        'email' => Icons.email_rounded,
        'website' => Icons.language_rounded,
        'other' => Icons.link_rounded,
        _ => null,
      };
  String? get assetIcon => switch (type) {
        'zalo' => 'assets/icons/zalo.png',
        'facebook' => 'assets/icons/facebook.png',
        _ => null,
      };
  Color get displayColor => switch (type) {
        'phone' => const Color(0xFF34C759),
        'zalo' => const Color(0xFF0068FF),
        'facebook' => const Color(0xFF1877F2),
        'email' => const Color(0xFFEA4335),
        'website' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };
}
