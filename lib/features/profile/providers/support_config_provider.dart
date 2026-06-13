import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class SupportConfigItem {
  final String title;
  final String? subtitle;
  final String icon;
  final String type;
  final String value;
  final String? color;

  const SupportConfigItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.type,
    required this.value,
    this.color,
  });

  factory SupportConfigItem.fromJson(Map<String, dynamic> j) =>
      SupportConfigItem(
        title:    j['title'] as String,
        subtitle: j['subtitle'] as String?,
        icon:     j['icon'] as String? ?? 'chat',
        type:     j['type'] as String? ?? 'url',
        value:    j['value'] as String,
        color:    j['color'] as String?,
      );
}

final supportConfigProvider =
    FutureProvider.autoDispose<List<SupportConfigItem>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/support-configs');
  final list = (res.data['data'] as List? ?? []);
  return list
      .map((e) => SupportConfigItem.fromJson(e as Map<String, dynamic>))
      .toList();
});
