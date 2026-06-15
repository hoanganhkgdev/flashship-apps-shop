import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class SupportConfigItem {
  final String title;
  final String type;
  final String value;

  const SupportConfigItem({
    required this.title,
    required this.type,
    required this.value,
  });

  factory SupportConfigItem.fromJson(Map<String, dynamic> j) =>
      SupportConfigItem(
        title: j['title'] as String,
        type:  j['type'] as String? ?? 'other',
        value: j['value'] as String,
      );

  Uri get uri => Uri.parse(value);

  // null = dùng asset PNG
  IconData? get materialIcon => switch (type) {
    'phone'   => Icons.phone_rounded,
    'email'   => Icons.email_rounded,
    'website' => Icons.language_rounded,
    'other'   => Icons.link_rounded,
    _         => null,
  };

  String? get assetIcon => switch (type) {
    'zalo'     => 'assets/icons/zalo.png',
    'facebook' => 'assets/icons/facebook.png',
    _          => null,
  };

  Color get displayColor => switch (type) {
    'phone'    => const Color(0xFF34C759),
    'zalo'     => const Color(0xFF0068FF),
    'facebook' => const Color(0xFF1877F2),
    'email'    => const Color(0xFFEA4335),
    'website'  => const Color(0xFF6B7280),
    _          => const Color(0xFF6B7280),
  };
}

final supportConfigProvider =
    FutureProvider.autoDispose<List<SupportConfigItem>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/support-configs');
  final list = (res.data['data'] as List? ?? []);
  return list
      .map((e) => SupportConfigItem.fromJson(e as Map<String, dynamic>))
      .toList();
});
